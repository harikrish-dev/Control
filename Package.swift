// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Control",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Control", targets: ["Control"])
    ],
    targets: [
        .executableTarget(
            name: "Control",
            path: "Control",
            resources: [
                .process("Assets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
