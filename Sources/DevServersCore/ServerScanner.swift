import Darwin
import Foundation

/// 로컬에서 LISTEN 중인 서버 프로세스 하나.
public struct DevServer: Identifiable, Hashable, Sendable {
    public let pid: Int32
    public let pgid: Int32
    public let ports: [Int]
    /// lsof 의 COMMAND 컬럼 (최대 9자로 잘림)
    public let processName: String
    /// `ps -o command=` 전체 실행 명령
    public let command: String
    public let cwd: String?
    public let projectName: String
    public let kind: String
    public let isNode: Bool
    /// `ps -o %cpu=` (최근 사용률의 감쇠 평균, 멀티코어면 100 초과 가능)
    public let cpu: Double

    public var id: Int32 { pid }

    /// 홈 디렉터리를 `~` 로 치환한 경로
    public var displayPath: String {
        guard let cwd else { return "-" }
        let home = NSHomeDirectory()
        if cwd == home { return "~" }
        if cwd.hasPrefix(home + "/") { return "~" + cwd.dropFirst(home.count) }
        return cwd
    }
}

public enum ServerScanner {
    // MARK: - Scan

    public static func scan(includeAll: Bool = false) -> [DevServer] {
        let listeners = listeningPorts()
        guard !listeners.isEmpty else { return [] }

        let pids = Array(listeners.keys)
        let psInfo = processInfo(pids: pids)
        let cwds = workingDirectories(pids: pids)

        let servers: [DevServer] = pids.compactMap { pid in
            guard let listener = listeners[pid] else { return nil }
            let info = psInfo[pid]
            let command = info?.command ?? listener.name
            let cwd = cwds[pid]
            let isNode = detectNode(processName: listener.name, command: command)
            if !includeAll && !isNode { return nil }

            return DevServer(
                pid: pid,
                pgid: info?.pgid ?? pid,
                ports: listener.ports.sorted(),
                processName: listener.name,
                command: command,
                cwd: cwd,
                projectName: projectName(cwd: cwd, fallback: listener.name),
                kind: detectKind(command: command, isNode: isNode, processName: listener.name),
                isNode: isNode,
                cpu: info?.cpu ?? 0
            )
        }

        return servers.sorted {
            ($0.ports.first ?? .max, $0.pid) < ($1.ports.first ?? .max, $1.pid)
        }
    }

    // MARK: - Terminate

    /// 프로세스 그룹에 SIGTERM → 3초 내 종료되지 않으면 SIGKILL. 블로킹 호출이므로 백그라운드에서 사용.
    /// - Returns: 최종적으로 프로세스가 사라졌는지 여부
    @discardableResult
    public static func terminate(pid: Int32, pgid: Int32, timeout: TimeInterval = 3) -> Bool {
        // 자기 자신의 그룹이거나 launchd/커널 그룹이면 그룹 전체를 죽이지 않고 해당 PID 만 대상으로 한다.
        let useGroup = pgid > 1 && pgid != getpgrp()
        let target: pid_t = useGroup ? -pgid : pid

        if kill(target, SIGTERM) != 0, useGroup {
            kill(pid, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isAlive(pid) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }

        kill(target, SIGKILL)
        kill(pid, SIGKILL)
        Thread.sleep(forTimeInterval: 0.3)
        return !isAlive(pid)
    }

    public static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: - lsof: LISTEN ports

    struct Listener {
        var name: String
        var ports: Set<Int>
    }

    /// `lsof -iTCP -sTCP:LISTEN -n -P` → PID 별로 포트 묶음
    static func listeningPorts() -> [Int32: Listener] {
        let output = run("/usr/sbin/lsof", ["-iTCP", "-sTCP:LISTEN", "-n", "-P"])
        var result: [Int32: Listener] = [:]

        for line in output.split(separator: "\n").dropFirst() {
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 9, let pid = Int32(tokens[1]) else { continue }
            // NAME 컬럼: "*:3000", "127.0.0.1:5173", "[::1]:6006" — "(LISTEN)" 앞의 토큰
            guard let address = tokens.last(where: { $0.contains(":") }),
                  let colon = address.lastIndex(of: ":"),
                  let port = Int(address[address.index(after: colon)...])
            else { continue }

            let name = String(tokens[0]).replacingOccurrences(of: "\\x20", with: " ")
            result[pid, default: Listener(name: name, ports: [])].ports.insert(port)
        }
        return result
    }

    // MARK: - lsof: cwd

    /// `lsof -a -p <PID,...> -d cwd -Fn` (여러 PID 를 한 번에 조회)
    static func workingDirectories(pids: [Int32]) -> [Int32: String] {
        let list = pids.map(String.init).joined(separator: ",")
        let output = run("/usr/sbin/lsof", ["-a", "-p", list, "-d", "cwd", "-Fpn"])
        var result: [Int32: String] = [:]
        var current: Int32?

        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": current = Int32(value)
            case "n": if let pid = current { result[pid] = value }
            default: break
            }
        }
        return result
    }

    // MARK: - ps

    struct PSInfo {
        let pgid: Int32
        let cpu: Double
        let command: String
    }

    /// `ps -o pid=,pgid=,%cpu=,command= -p <PID,...>`
    static func processInfo(pids: [Int32]) -> [Int32: PSInfo] {
        let list = pids.map(String.init).joined(separator: ",")
        let output = run("/bin/ps", ["-o", "pid=,pgid=,%cpu=,command=", "-p", list])
        var result: [Int32: PSInfo] = [:]
        let pattern = #/^\s*(\d+)\s+(\d+)\s+([\d.]+)\s+(.*)$/#

        for line in output.split(separator: "\n") {
            guard let match = String(line).wholeMatch(of: pattern),
                  let pid = Int32(match.1),
                  let pgid = Int32(match.2)
            else { continue }
            result[pid] = PSInfo(pgid: pgid, cpu: Double(match.3) ?? 0, command: String(match.4))
        }
        return result
    }

    // MARK: - package.json

    static func projectName(cwd: String?, fallback: String) -> String {
        guard let cwd, cwd != "/" else { return fallback }
        let url = URL(fileURLWithPath: cwd)
        let packageURL = url.appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: packageURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = json["name"] as? String, !name.isEmpty
        {
            return name
        }
        return url.lastPathComponent
    }

    // MARK: - Classification

    static func detectNode(processName: String, command: String) -> Bool {
        if processName.lowercased() == "node" { return true }
        let first = command.split(separator: " ").first.map(String.init) ?? ""
        if (first as NSString).lastPathComponent == "node" { return true }
        // next dev 의 워커는 process.title 을 "next-server (vX.Y.Z)" 로 바꾼다
        return command.hasPrefix("next-server")
    }

    /// 순서가 중요하다: storybook 은 내부적으로 vite/webpack 을 쓰므로 먼저 검사.
    static let kindRules: [(label: String, needles: [String])] = [
        ("Storybook", ["storybook"]),
        ("Next.js", ["next-server", "next dev", "next start", "/.bin/next", "next/dist/", "/next "]),
        ("Nuxt", ["nuxt"]),
        ("Astro", ["astro"]),
        ("Remix", ["remix"]),
        ("SvelteKit", ["svelte-kit"]),
        ("Vite", ["vite"]),
        ("webpack", ["webpack"]),
        ("CRA", ["react-scripts"]),
        ("Angular", ["ng serve", "@angular"]),
        ("Expo", ["expo start", "/expo/", "/.bin/expo"]),
        ("NestJS", ["nest start", "@nestjs"]),
        ("Parcel", ["parcel"]),
        ("nodemon", ["nodemon"]),
        ("tsx", ["/tsx ", "/.bin/tsx", "tsx watch"]),
        ("ts-node", ["ts-node"]),
        ("json-server", ["json-server"]),
    ]

    static func detectKind(command: String, isNode: Bool, processName: String) -> String {
        // node 가 아닌 프로세스는 명령 인자에 우연히 포함된 단어로 오탐하기 쉬우므로 프로세스명을 그대로 쓴다
        guard isNode else { return processName }
        let lower = command.lowercased()
        for rule in kindRules where rule.needles.contains(where: { lower.contains($0) }) {
            return rule.label
        }
        return isNode ? "Node" : processName
    }

    // MARK: - Process helper

    static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        // 파이프 버퍼가 가득 차 데드락 나지 않도록 먼저 끝까지 읽고 나서 wait
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
