// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "JustSing",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "JustSing", targets: ["JustSing"])
    ],
    targets: [
        .target(name: "CAtomics"),
        .executableTarget(
            name: "JustSing",
            dependencies: ["CAtomics"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreML"),
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
