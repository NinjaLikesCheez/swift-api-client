// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "swift-api-client",
	platforms: [
		.iOS(.v18),
		.macOS(.v15),
		.visionOS(.v2),
		.tvOS(.v18),
		.watchOS(.v11)
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "APIClient",
			targets: ["APIClient"]
		),
		.executable(name: "api-client", targets: ["api-client"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "APIClient",
			dependencies: [
				.product(name: "Logging", package: "swift-log")
			]
		),
		.executableTarget(
			name: "api-client",
			dependencies: ["APIClient"]
		),
		.testTarget(
			name: "APIClientTests",
			dependencies: ["APIClient"]
		)
	]
)
