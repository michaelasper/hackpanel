// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HackPanel",
    platforms: [
        // "macOS 14" baseline; adjust as needed. (Xcode will map this to the nearest macOS SDK.)
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HackPanelApp", targets: ["HackPanelApp"]),
        .library(name: "HackPanelGateway", targets: ["HackPanelGateway"]),
        .library(name: "HackPanelGatewayMocks", targets: ["HackPanelGatewayMocks"])
    ],
    targets: [
        .target(
            name: "HackPanelGateway",
            path: "Sources/HackPanelGateway"
        ),
        .target(
            name: "HackPanelGatewayMocks",
            dependencies: ["HackPanelGateway"],
            path: "Sources/HackPanelGatewayMocks"
        ),
        .executableTarget(
            name: "HackPanelApp",
            dependencies: ["HackPanelGateway", "HackPanelGatewayMocks"],
            path: "Sources/HackPanelApp"
        ),
        .testTarget(
            name: "HackPanelGatewayTests",
            dependencies: ["HackPanelGateway"],
            path: "Tests/HackPanelGatewayTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
