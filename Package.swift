// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-mime",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "MIME", targets: ["MIME"])
    ],
    targets: [
        .target(
            name: "MIME"
        ),
        .testTarget(
            name: "MIMETests",
            dependencies: ["MIME"]
        ),
        .executableTarget(
            name: "Mosaic",
            dependencies: ["MIME"],
            path: "Demo/Mosaic"
        ),
    ]
)
