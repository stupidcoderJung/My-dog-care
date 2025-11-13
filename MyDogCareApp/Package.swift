// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyDogCareApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MyDogCareApp",
            targets: ["MyDogCareApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/clerkinc/clerk-ios.git", from: "1.8.0")
    ],
    targets: [
        .target(
            name: "MyDogCareApp",
            dependencies: [
                .product(name: "ClerkSDK", package: "clerk-ios")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "MyDogCareAppTests",
            dependencies: ["MyDogCareApp"],
            path: "Tests"
        )
    ]
)
