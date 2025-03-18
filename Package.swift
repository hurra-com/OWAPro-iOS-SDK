// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HurraS2SSDK",
    platforms: [.iOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HurraS2SSDK",
            targets: ["HurraS2SSDK"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HurraS2SSDK"),
        .testTarget(
            name: "HurraS2SSDKTests",
            dependencies: ["HurraS2SSDK"],
            resources: [
                .copy("Resources/testCredentials.plist")
            ]
        ),
    ]
)
