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
		// Depend on the latest Swift 5.9 prerelease of SwiftSyntax
		//.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0-swift-DEVELOPMENT-SNAPSHOT-2023-07-10-a"),//"509.0.0-swift-5.9-DEVELOPMENT-SNAPSHOT-2023-04-25-b"),
		.package(url: "https://github.com/apple/swift-syntax.git", revision: "swift-5.9-DEVELOPMENT-SNAPSHOT-2023-07-10-a"),
	],
	targets: [
		.macro(
			name: "GraphQLMacros",
			dependencies: [
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax")
			]
		),
		.target(
			name: "GraphQLBuilder",
			dependencies: ["GraphQLMacros"]
		),
		.executableTarget(name: "GraphQLClient", dependencies: ["GraphQLBuilder"]),
		.executableTarget(
			name: "GraphQLSourceGen",
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
