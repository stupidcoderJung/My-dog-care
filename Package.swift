// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyDogCare",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MyDogCare",
            targets: ["MyDogCare"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/clerkinc/clerk-ios", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "MyDogCare",
            dependencies: [
                .product(name: "ClerkSDK", package: "clerk-ios")
            ],
            path: "MyDogCare",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MyDogCareTests",
            dependencies: ["MyDogCare"]
        )
    ]
)
