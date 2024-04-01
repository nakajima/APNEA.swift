// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "APNEA",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(name: "APNEAClient", targets: ["APNEAClient"]),
		.executable(name: "Server", targets: ["Server"]),
	],
	dependencies: [
		.package(url: "https://github.com/hummingbird-project/hummingbird", branch: "main"),
		.package(url: "https://github.com/swift-server-community/APNSwift", branch: "main"),
	],
	targets: [
		.target(
			name: "APNEAClient",
			dependencies: [
				"APNEACore",
				.product(name: "APNS", package: "APNSwift"),
			]
		),
		.target(
			name: "APNEACore",
			dependencies: [
				.product(name: "APNS", package: "APNSwift"),
			]
		),
		.executableTarget(
			name: "Server",
			dependencies: [
				"APNEACore",
				.product(name: "Hummingbird", package: "hummingbird"),
				.product(name: "APNS", package: "APNSwift"),
			]
		),
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.testTarget(
			name: "APNEATests",
			dependencies: ["Server"]
		),
	]
)
