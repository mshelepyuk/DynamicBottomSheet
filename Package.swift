// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicBottomSheet",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "DynamicBottomSheet",
            targets: ["DynamicBottomSheet"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0")
    ],
    targets: [
        .target(
            name: "DynamicBottomSheet",
            dependencies: ["SnapKit"],
            path: "Sources"
        )
    ]
)
