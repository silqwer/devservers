// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DevServers",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DevServers", targets: ["DevServers"]),
        .executable(name: "devservers-scan", targets: ["devservers-scan"]),
    ],
    targets: [
        .target(name: "DevServersCore"),
        .executableTarget(name: "devservers-scan", dependencies: ["DevServersCore"]),
        .executableTarget(name: "DevServers", dependencies: ["DevServersCore"]),
    ]
)
