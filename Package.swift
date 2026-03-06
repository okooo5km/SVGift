// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SVGift",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .watchOS(.v9),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "SVGift",
      targets: ["SVGift"]
    ),
    .executable(
      name: "svgift",
      targets: ["SVGiftCLI"]
    ),
    .executable(
      name: "SVGift-dev",
      targets: ["SVGift-dev"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "release/6.2"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
  ],
  targets: [
    .target(
      name: "SVGift"
    ),
    .executableTarget(
      name: "SVGiftCLI",
      dependencies: [
        .target(name: "SVGift"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .executableTarget(
      name: "SVGift-dev",
      dependencies: [
        .target(name: "SVGift"),
      ]
    ),
    .testTarget(
      name: "SVGiftTests",
      dependencies: [
        "SVGift",
        .product(name: "Testing", package: "swift-testing"),
      ]
    ),
  ]
)
