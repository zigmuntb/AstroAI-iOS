// swift-tools-version: 6.0
// Astronomy Engine by Don Cross (MIT): https://github.com/cosinekitty/astronomy

import PackageDescription

let package = Package(
    name: "AstronomyEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AstronomyEngine", targets: ["AstronomyEngine"])
    ],
    targets: [
        .target(
            name: "CAstronomyEngine",
            publicHeadersPath: "include"
        ),
        .target(
            name: "AstronomyEngine",
            dependencies: ["CAstronomyEngine"]
        )
    ]
)
