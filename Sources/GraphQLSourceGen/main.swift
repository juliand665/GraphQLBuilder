import Foundation
import CodeGenHelpers
import ArgumentParser

@main
struct Generate: AsyncParsableCommand {
	@Argument(help: "The URL of the GraphQL endpoint whose schema we're fetching.")
	var serverURL: String
	
	@Option(name: .shortAndLong, parsing: .upToNextOption, help: "HTTP headers to pass along with the request.")
	var headers: [String] = []
	
	func run() async throws {
		let queryFile = Bundle.module.url(forResource: "introspect", withExtension: "gql")!
		let query = try String(contentsOf: queryFile)
		
		guard let serverURL = URL(string: serverURL) else {
			fatalError("invalid server URL: \(serverURL)")
		}
		
		var request = URLRequest(url: serverURL)
		request.httpMethod = "POST"
		request.httpBody = try JSONEncoder().encode(Request(query: query))
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		for header in headers {
			if let splitIndex = header.firstIndex(of: ":") {
				let name = String(header.prefix(upTo: splitIndex))
				let value = String(header.suffix(from: splitIndex).dropFirst().drop { $0.isWhitespace })
				log("- passing header \(name): \(value)")
				request.setValue(value, forHTTPHeaderField: name)
			} else {
				request.setValue(nil, forHTTPHeaderField: header)
			}
		}
		log("sending introspection request to \(serverURL)")
		
		let (rawSchema, _) = try await URLSession.shared.data(for: request)
		let rawDesc = rawSchema.count < 1000 ? String(bytes: rawSchema, encoding: .utf8)! : "<\(rawSchema.count) bytes>"
		log("received response: \(rawDesc)")
		
		let response = try JSONDecoder().decode(SchemaResponse.self, from: rawSchema)
		guard let schema = response.data?.schema else {
			log("errors encountered!")
			for error in response.errors! {
				log("- \(error.message)")
			}
			fatalError()
		}
		
		log("generating swift code")
		let code = CodeGenerator.generate { code in
			code.writeLine("import GraphQLBuilder")
			code.newLine()
			code.writeLine("/// Schema for \(serverURL.absoluteString)")
			
			code.writeBlock("enum GraphQL") {
				for type in schema.types {
					code.writeCode(for: type)
				}
			}
			
			let requiredScalars: [String] = schema.types.lazy
				.filter { $0.kind == .scalar && builtinScalars[$0.name] == nil }
				.map(\.name)
			if !requiredScalars.isEmpty {
				log("")
				log("This schema uses custom scalar types!")
				log("Make sure you define these somewhere in your code:")
				for scalar in requiredScalars {
					log("struct \(scalar): GraphQLScalar { ... }")
				}
				if requiredScalars.contains("Date") {
					log("For Date, instead of importing Foundation, you can re-export it with a typealias (or write your own if you're not using Foundation):")
					log("typealias Date = Foundation.Date")
				}
				log("You can also nest these types in an extension of the GraphQL namespace enum that the generated code lives in.")
				log("")
			}
		}
		
		let filename = "Schema.generated.swift"
		log("writing generated schema")
		try code.write(toFile: filename, atomically: false, encoding: .utf8)
		log("schema written to \(filename)")
	}
}
