import AppKit
import DevServersCore
import SwiftUI

@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [DevServer] = []
    @Published private(set) var terminating: Set<Int32> = []
    @Published private(set) var lastUpdated: Date?
    /// 메뉴바 아이콘의 현재 프레임 (전원 켜진 칸 수 + 활동 LED 비트마스크)
    @Published private(set) var iconFrame = RackIcon.Frame(powered: 0, activityMask: 0)
    @Published var showAll: Bool {
        didSet {
            UserDefaults.standard.set(showAll, forKey: Self.showAllKey)
            refresh(force: true)
        }
    }

    private static let showAllKey = "showAllProcesses"
    private static let interval: TimeInterval = 3
    private var isScanning = false
    private var pendingRefresh = false
    private var timer: Timer?
    private var blinkTimer: Timer?
    private var blinkInterval: TimeInterval = 0

    init() {
        showAll = UserDefaults.standard.bool(forKey: Self.showAllKey)
        refresh()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 스캔은 백그라운드에서 실행. 진행 중이면 겹치지 않게 하고, force 요청은 끝난 뒤 한 번 더 돈다.
    func refresh(force: Bool = false) {
        guard !isScanning else {
            if force { pendingRefresh = true }
            return
        }
        isScanning = true
        let includeAll = showAll
        Task.detached(priority: .utility) {
            let result = Self.applyDemoFilter(ServerScanner.scan(includeAll: includeAll))
            await MainActor.run {
                self.servers = result
                self.lastUpdated = Date()
                self.updateBlinking()
                self.isScanning = false
                if self.pendingRefresh {
                    self.pendingRefresh = false
                    self.refresh()
                }
            }
        }
    }

    /// 데모/녹화용: DEVSERVERS_DEMO_ROOT 하위에서 실행된 서버만 표시 (scripts/demo-servers.sh 참고)
    nonisolated private static func applyDemoFilter(_ servers: [DevServer]) -> [DevServer] {
        guard let root = ProcessInfo.processInfo.environment["DEVSERVERS_DEMO_ROOT"], !root.isEmpty else {
            return servers
        }
        // /tmp → /private/tmp 처럼 lsof 가 돌려주는 실제 경로와 맞춘다
        // (URL.resolvingSymlinksInPath 는 /private 를 다시 떼어내므로 realpath 를 쓴다)
        let resolved = realpath(root, nil).map { pointer in
            defer { free(pointer) }
            return String(cString: pointer)
        } ?? root
        return servers.filter { $0.cwd?.hasPrefix(resolved) == true }
    }

    func terminate(_ server: DevServer) {
        guard !terminating.contains(server.pid) else { return }
        terminating.insert(server.pid)
        let pid = server.pid
        let pgid = server.pgid
        Task.detached(priority: .userInitiated) {
            ServerScanner.terminate(pid: pid, pgid: pgid)
            await MainActor.run {
                self.terminating.remove(pid)
                self.servers.removeAll { $0.pid == pid && !ServerScanner.isAlive(pid) }
                self.updateBlinking()
                self.refresh(force: true)
            }
        }
    }

    // MARK: - Menu bar icon animation

    /// 서버 CPU 합계에 비례해 활동 LED 깜빡임 속도를 정한다 (RunCat 방식).
    /// 0% → 0.9초 간격으로 느긋하게, 100% 이상 → 0.07초 간격으로 정신없이.
    private func updateBlinking() {
        let powered = min(servers.count, RackIcon.unitCount)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard powered > 0, !reduceMotion else {
            blinkTimer?.invalidate()
            blinkTimer = nil
            blinkInterval = 0
            iconFrame = RackIcon.Frame(powered: powered, activityMask: powered > 0 ? (1 << powered) - 1 : 0)
            return
        }

        let cpu = servers.reduce(0) { $0 + $1.cpu }
        let load = min(cpu / 100, 1)
        let interval = 0.9 - (0.9 - 0.07) * sqrt(load)

        // 간격이 크게 바뀔 때만 타이머를 다시 만든다 (매 스캔마다 리듬이 끊기지 않도록)
        guard blinkTimer == nil || abs(interval - blinkInterval) / blinkInterval > 0.15 else { return }
        blinkInterval = interval
        blinkTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.blink() }
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
        blink()
    }

    private func blink() {
        let powered = min(servers.count, RackIcon.unitCount)
        var mask = 0
        for unit in 0..<powered where Bool.random() {
            mask |= 1 << unit
        }
        iconFrame = RackIcon.Frame(powered: powered, activityMask: mask)
    }

    func terminateAll() {
        servers.forEach(terminate)
    }

    func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ server: DevServer) {
        guard let cwd = server.cwd else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: cwd, isDirectory: true))
    }
}
