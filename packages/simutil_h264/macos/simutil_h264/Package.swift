// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "simutil_h264",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "simutil-h264", targets: ["simutil_h264"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "simutil_h264",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
