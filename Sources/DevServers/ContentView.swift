import DevServersCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ServerStore
    @State private var isConfirmingKillAll = false
    @State private var listContentHeight: CGFloat = 0
    @State private var window: NSWindow?

    private static let maxListHeight: CGFloat = 440

    var body: some View {
        VStack(spacing: 0) {
            header
            if isConfirmingKillAll {
                killAllConfirmation
            }
            serverList
            footer
        }
        .padding(6)
        .frame(width: 420)
        .background(Rack.chassis)
        .environment(\.colorScheme, .dark)
        .fixedSize(horizontal: false, vertical: true)
        // MenuBarExtra(.window) 패널은 내용이 줄어도 스스로 줄어들지 않으므로 직접 창 크기를 맞춘다
        .background(WindowAccessor { if window !== $0 { window = $0 } })
        .background(HeightReader(RootHeightKey.self))
        .onPreferenceChange(RootHeightKey.self) { fitWindow(toContentHeight: $0) }
        .onAppear { store.refresh(force: true) }
        .onDisappear { isConfirmingKillAll = false }
    }

    // MARK: - Rack top (header)

    private var header: some View {
        HStack(spacing: 8) {
            Text("DEVSERVERS")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(Rack.engraved)
                .shadow(color: .black.opacity(0.8), radius: 0, y: -0.5)
            LCD(text: String(format: "%02dU", store.servers.count))
            Spacer()
            Button {
                store.refresh(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(HardwareButtonStyle())
            .help("새로고침")

            Button("전체 종료") { isConfirmingKillAll = true }
                .buttonStyle(HardwareButtonStyle(tint: Rack.red))
                .disabled(store.servers.isEmpty)
                .help("모든 서버 종료")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .modifier(Faceplate())
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var killAllConfirmation: some View {
        VStack(spacing: 0) {
            HazardStripe().frame(height: 4)
            HStack(spacing: 8) {
                LED(color: Rack.amber, isOn: true)
                Text("\(store.servers.count)개 서버를 모두 종료할까요?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Rack.amber)
                Spacer()
                Button("취소") { isConfirmingKillAll = false }
                    .buttonStyle(HardwareButtonStyle())
                Button("모두 종료") {
                    store.terminateAll()
                    isConfirmingKillAll = false
                }
                .buttonStyle(HardwareButtonStyle(tint: Rack.red, isProminent: true))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(red: 0.16, green: 0.12, blue: 0.04))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.top, 3)
    }

    // MARK: - Rack units

    @ViewBuilder
    private var serverList: some View {
        if store.servers.isEmpty {
            RackUnit {
                HStack(spacing: 10) {
                    VentSlots(count: 5)
                    Text(store.showAll ? "EMPTY SLOT · LISTEN 중인 프로세스 없음" : "EMPTY SLOT · 실행 중인 node 서버 없음")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Rack.engraved)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    VentSlots(count: 5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
            }
            .padding(.vertical, 3)
        } else {
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(store.servers) { server in
                        ServerRow(server: server, isTerminating: store.terminating.contains(server.pid))
                    }
                }
                .padding(.vertical, 3)
                .background(HeightReader(ListHeightKey.self))
                .onPreferenceChange(ListHeightKey.self) { listContentHeight = $0 }
            }
            .scrollIndicators(.never)
            // ScrollView 는 가용 공간만큼 늘어나므로 내용 높이로 명시 (최대 maxListHeight)
            .frame(height: min(max(listContentHeight, 1), Self.maxListHeight))
        }
    }

    private func fitWindow(toContentHeight height: CGFloat) {
        guard let window, height > 0 else { return }
        var frame = window.frame
        let currentHeight = window.contentRect(forFrameRect: frame).height
        let delta = height - currentHeight
        guard abs(delta) >= 1 else { return }
        // 메뉴바에 붙은 위쪽 가장자리는 고정하고 아래로 늘이거나 줄인다
        frame.size.height += delta
        frame.origin.y -= delta
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Rack base (footer)

    private var footer: some View {
        HStack {
            Toggle("ALL PROCS", isOn: $store.showAll)
                .toggleStyle(RockerToggleStyle())
                .help("node 가 아닌 프로세스까지 모두 보기")
            Spacer()
            // 서버 전원(초록 ⏻)과 헷갈리지 않도록 앱 종료는 회색 ⏏ + QUIT 각인
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("QUIT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(Rack.engraved)
            }
            .buttonStyle(HardwareButtonStyle())
            .keyboardShortcut("q")
            .help("DevServers 앱 종료 (⌘Q) · 실행 중인 서버는 그대로 유지돼요")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .modifier(Faceplate())
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Server row (1U)

struct ServerRow: View {
    @EnvironmentObject private var store: ServerStore
    let server: DevServer
    let isTerminating: Bool
    @State private var isHovering = false

    var body: some View {
        RackUnit {
            HStack(spacing: 10) {
                VStack(spacing: 6) {
                    PowerLED(isTerminating: isTerminating)
                    ActivityLED(cpu: server.cpu, isOn: !isTerminating)
                }
                .help(String(format: "CPU %.1f%%", server.cpu))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(server.projectName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .help(server.command)
                        KindPlate(kind: server.kind, isNode: server.isNode)
                    }
                    HStack(spacing: 5) {
                        ForEach(server.ports, id: \.self) { port in
                            Button { store.openInBrowser(port: port) } label: {
                                LCD(text: ":\(String(port))")
                            }
                            .buttonStyle(.plain)
                            .help("http://localhost:\(String(port)) 열기")
                        }
                        Text("PID \(String(server.pid))")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Rack.engraved.opacity(0.7))
                    }
                }

                Spacer(minLength: 4)
                VentSlots(count: 4)
                actions
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .overlay(Color.white.opacity(isHovering ? 0.03 : 0))
        }
        .opacity(isTerminating ? 0.6 : 1)
        .onHover { isHovering = $0 }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            Button {
                if let port = server.ports.first { store.openInBrowser(port: port) }
            } label: { Image(systemName: "safari") }
                .buttonStyle(HardwareButtonStyle(isSquare: true))
                .disabled(server.ports.isEmpty)
                .help("브라우저로 열기")

            Button { store.revealInFinder(server) } label: { Image(systemName: "folder") }
                .buttonStyle(HardwareButtonStyle(isSquare: true))
                .disabled(server.cwd == nil)
                .help("Finder에서 열기\n\(server.displayPath)")

            PowerButton(help: "서버 종료 (SIGTERM → 3초 후 SIGKILL)") { store.terminate(server) }
                .disabled(isTerminating)
        }
    }
}
