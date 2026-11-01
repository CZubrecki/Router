// swift-tools-version: 6.0

import AppleProductTypes
import PackageDescription

let package = Package(
	name: "CoverSwapDemo",
	platforms: [.iOS("18.0")],
	products: [
		.iOSApplication(
			name: "CoverSwapDemo",
			targets: ["AppModule"],
			bundleIdentifier: "dev.czubrecki.router.coverswapdemo",
			teamIdentifier: "R8526Y5639",
			displayVersion: "1.0",
			bundleVersion: "1",
			appIcon: .placeholder(icon: .bicycle),
			accentColor: .presetColor(.green),
			supportedDeviceFamilies: [.phone],
			supportedInterfaceOrientations: [.portrait],
		),
	],
	dependencies: [
		.package(path: "../.."),
	],
	targets: [
		.executableTarget(
			name: "AppModule",
			dependencies: [.product(name: "RouterUI", package: "Router")],
			path: "Sources",
		),
	],
)
