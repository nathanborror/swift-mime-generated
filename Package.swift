// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-mime-generated",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "MIME", targets: ["MIME"]),
    ],
    targets: [
        .target(name: "MIME"),
        .testTarget(name: "MIMETests", dependencies: ["MIME"]),
    ]
)
