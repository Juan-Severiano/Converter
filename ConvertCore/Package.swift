// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConvertCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConvertCore", targets: ["ConvertCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/ainame/Swift-WebP.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "ConvertCore",
            dependencies: [
                .product(name: "WebP", package: "Swift-WebP")
            ]
        ),
        .testTarget(
            name: "ConvertCoreTests",
            dependencies: ["ConvertCore"]
        )
    ]
)
