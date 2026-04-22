// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UrlImageView",
    platforms: [.iOS(.v13),.macOS(.v11)],
    products: [
        .library(
            name: "UrlImageView",
            targets: ["UrlImageView"]),
    ],
    targets: [
        .target(
            name: "UrlImageView",
            dependencies: []),
        .testTarget(
            name: "UrlImageViewTests",
            dependencies: ["UrlImageView"]),
    ]
)
