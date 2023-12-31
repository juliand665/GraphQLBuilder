// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
	name: "GraphQLBuilder",
	platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
	products: [
		.library(
			name: "GraphQLBuilder",
			targets: ["GraphQLBuilder"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.2.2")),
	],
	targets: [
		.target(name: "CodeGenHelpers"),
		.target(
			name: "GraphQLBuilder",
			dependencies: ["CodeGenHelpers"]
		),
		.executableTarget(name: "GraphQLClient", dependencies: ["GraphQLBuilder"]),
		.executableTarget(
			name: "GraphQLSourceGen",
			dependencies: [
				"CodeGenHelpers",
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			],
			resources: [
				.copy("introspect.gql"),
			]
		),
		.testTarget(
			name: "GraphQLBuilderTests",
			dependencies: ["GraphQLBuilder"]
		),
	]
)
