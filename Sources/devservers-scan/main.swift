import DevServersCore
import Foundation

// 사용법: devservers-scan [--all]
let includeAll = CommandLine.arguments.contains("--all")
let start = Date()
let servers = ServerScanner.scan(includeAll: includeAll)
let elapsed = Int(Date().timeIntervalSince(start) * 1000)

func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? String(s.prefix(width)) : s + String(repeating: " ", count: width - s.count)
}

print(pad("PID", 7), pad("PGID", 7), pad("PORTS", 14), pad("KIND", 11), pad("CPU%", 6), pad("PROJECT", 26), "PATH")
for s in servers {
    print(
        pad(String(s.pid), 7),
        pad(String(s.pgid), 7),
        pad(s.ports.map(String.init).joined(separator: ","), 14),
        pad(s.kind, 11),
        pad(String(format: "%.1f", s.cpu), 6),
        pad(s.projectName, 26),
        s.displayPath
    )
    print("        └ \(s.command.prefix(120))")
}
print("\n\(servers.count) server(s)\(includeAll ? " (all processes)" : " (node only)") · scanned in \(elapsed)ms")

// 종료 로직 테스트용: devservers-scan --kill <PID>
if let i = CommandLine.arguments.firstIndex(of: "--kill"), i + 1 < CommandLine.arguments.count,
   let pid = Int32(CommandLine.arguments[i + 1]),
   let target = ServerScanner.scan(includeAll: true).first(where: { $0.pid == pid })
{
    let t = Date()
    let ok = ServerScanner.terminate(pid: target.pid, pgid: target.pgid, startTime: target.startTime)
    print("terminate \(pid) (pgid \(target.pgid)) → \(ok ? "stopped" : "still alive") in \(Int(Date().timeIntervalSince(t) * 1000))ms")
}
