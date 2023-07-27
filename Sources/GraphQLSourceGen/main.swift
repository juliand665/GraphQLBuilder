import Foundation
import CodeGenHelpers

let queryFile = Bundle.module.url(forResource: "introspect", withExtension: "gql")!
let query = try! String(contentsOf: queryFile)

guard
	CommandLine.arguments.indices.contains(1),
	let serverURL = URL(string: CommandLine.arguments[1])
else {
	fatalError("expected server URL as first argument")
}

var request = URLRequest(url: serverURL)
request.httpMethod = "POST"
request.httpBody = try! JSONEncoder().encode(Request(query: query))
request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
print("sending introspection request to \(serverURL)")

let (rawSchema, _) = try! await URLSession.shared.data(for: request)

let response = try! JSONDecoder().decode(SchemaResponse.self, from: rawSchema)
guard response.errors?.isEmpty != false else {
	print("errors encountered!")
	for error in response.errors! {
		print("-", error.message)
	}
	exit(1)
}

let schema = response.data!.schema

let generator = CodeGenerator()

generator.write("import GraphQLBuilder")

for type in schema.types {
	generator.writeCode(for: type)
}

print()
//print(code)
try generator.code.write(toFile: "Schema.generated.swift", atomically: false, encoding: .utf8)
