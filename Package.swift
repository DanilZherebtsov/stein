// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Stein",
    platforms: [
        .macOS(.v13) // Ventura+ (covers current + several previous recent releases)
    ],
    products: [
        .executable(name: "Stein", targets: ["SteinApp"])
    ],
    targets: [
        .executableTarget(
            name: "SteinApp",
            path: "Sources/SteinApp",
            resources: [.process("Resources")]
        )
    ]
)
