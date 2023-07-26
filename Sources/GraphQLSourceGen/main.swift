import Foundation

struct Request: Encodable {
	var query: String
	var variables: [String: Never] = [:]
}

struct SchemaResponse: Decodable {
	var data: Body?
	var errors: [GraphQLError]?
	
	struct Body: Decodable {
		var schema: Schema
	}
}

struct GraphQLError: Decodable, Error {
	var message: String
}

// MARK: -

print("reading query")
let queryFile = Bundle.module.url(forResource: "introspect", withExtension: "gql")!
let query = try! String(contentsOf: queryFile)
print("read query!")

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
//print(String(bytes: request.httpBody!, encoding: .utf8)!)
print("sending request to \(serverURL)")

let (rawSchema, _) = try! await URLSession.shared.data(for: request)
//print(String(bytes: rawSchema, encoding: .utf8)!)

let response = try! JSONDecoder().decode(SchemaResponse.self, from: rawSchema)
guard response.errors?.isEmpty != false else {
	print("errors encountered!")
	for error in response.errors! {
		print("-", error.message)
	}
	exit(1)
}

let schema = response.data!.schema
//dump(schema)

// MARK: -

let builtinScalars: [String: String] = [
	"Boolean": "Bool",
	"Int": "Int",
	"Float": "Double",
	"String": "String",
	"ID": "StringID",
]

extension TypeReference {
	func swiftName() -> String {
		let (typeName, nonNull) = info()
		return nonNull ? typeName : "\(typeName)?"
	}
	
	func graphQLName() -> String {
		switch kind {
		case .nonNull:
			return "\(ofType!.graphQLName())!"
		case .list:
			return "[\(ofType!.graphQLName())]"
		default:
			return name!
		}
	}
	
	private func info() -> (name: String, nonNull: Bool) {
		var typeName: String
		switch kind {
		case .nonNull:
			return (name: ofType!.info().name, nonNull: true)
		case .list:
			typeName = "[\(ofType!.swiftName())]"
		case .scalar:
			typeName = builtinScalars[name!] ?? name!
		default:
			typeName = name!
		}
		return (name: typeName, nonNull: false)
	}
}

final class CodeGenerator {
	var defaultIndent: String = "\t"
	
	var code = ""
	
	var indentation = ""
	func indent(by change: String? = nil, _ block: () -> Void) {
		let old = indentation
		indentation += change ?? defaultIndent
		block()
		indentation = old
	}
	
	func write() { write("") }
	func write(_ part: some StringProtocol, terminator: String = "\n") {
		let lines = part.split(separator: "\n", omittingEmptySubsequences: false)
		for (index, line) in lines.enumerated() {
			if code.isEmpty || code.last == "\n" {
				code += indentation
			}
			code += line
			let isLastLine = index == lines.count - 1
			code += isLastLine ? terminator : "\n"
		}
	}
}

extension CodeGenerator {
	func writeAsMultilineDocComment(_ part: (some StringProtocol)?) {
		guard let part else { return }
		write("/**")
		write(part)
		write("*/")
	}
	
	func writeAsInlineDocComment(_ part: (some StringProtocol)?) {
		guard let part else { return }
		indent(by: "/// ") {
			write(part)
		}
	}
	
	func writeBlock(_ header: some StringProtocol, contents: () -> Void) {
		write("\(header) {")
		indent(contents)
		write("}")
	}
	
	func writeCode(for type: TypeInfo) {
		guard !type.name.hasPrefix("__") else {
			print("skipping introspection type \(type.name)")
			return
		}
		// TODO: deprecation?
		// TODO: custom scalars
		// TODO: interfaces
		// TODO: unions
		switch type.kind {
		case .object:
			// including metatypes in case people need them
			write()
			writeAsMultilineDocComment(type.description)
			writeObjectCode(for: type)
		case .scalar:
			guard !builtinScalars.keys.contains(type.name) else { return }
			print("skipping scalar of type \(type.name)")
		case .enum:
			write()
			writeAsMultilineDocComment(type.description)
			writeEnumCode(for: type)
		case .inputObject:
			write()
			writeAsMultilineDocComment(type.description)
			writeInputObjectCode(for: type)
		case let other:
			print("skipping other type \(type.name) of kind \(other)")
		}
	}
	
	func writeObjectCode(for type: TypeInfo) {
		writeBlock("struct \(type.name): GraphQLObject") {
			write("private var source: any DataSource")
			write()
			write("init(source: any DataSource) { self.source = source }")
			
			for (field, key) in zip(type.fields!, FieldKeys()) {
				write()
				writeAsInlineDocComment(field.description)
				let argDefs = field.args
					.lazy
					.map {
						let defaultPart = $0.requiresValue() ? "" : " = nil"
						return "\($0.name): \($0.type.swiftName())\(defaultPart)"
					}
					.joined(separator: ", ")
				let typeName = field.type.swiftName()
				writeBlock("func \(field.name.escapedIfNeeded)(\(argDefs)) -> \(typeName)") {
					let function = field.type.requiresSelection ? "object" : "scalar"
					write(
						#"source.\#(function)(access: .init(key: "\#(key)", field: "\#(field.name)", args: ["#,
						terminator: field.args.isEmpty ? "" : "\n"
					)
					indent {
						for arg in field.args {
							write(#".init(name: "\#(arg.name)", type: "\#(arg.type.graphQLName())", value: \#(arg.name)),"#)
						}
					}
					write(#"]))"#)
				}
			}
		}
	}
	
	func writeEnumCode(for type: TypeInfo) {
		writeBlock("enum \(type.name): String, GraphQLScalar, CaseIterable") {
			for value in type.enumValues! {
				writeAsInlineDocComment(value.description)
				if value.name.contains(where: \.isLowercase) {
					write("case \(value.name.escapedIfNeeded)")
				} else {
					let camelCased = toCamelCase(screamingSnake: value.name)
					write("case \(camelCased.escapedIfNeeded) = \"\(value.name)\"")
				}
			}
		}
	}
	
	func writeInputObjectCode(for type: TypeInfo) {
		writeBlock("struct \(type.name): InputValue") {
			for field in type.inputFields! {
				writeAsInlineDocComment(field.description)
				let fieldName = field.name.escapedIfNeeded
				let type = field.type.swiftName()
				if let defaultValue = field.defaultValue {
					write("var \(fieldName): \(type) = \(defaultValue)")
				} else {
					write("var \(fieldName): \(type)")
				}
			}
		}
	}
}

extension InputValue {
	func requiresValue() -> Bool {
		defaultValue == nil && type.kind == .nonNull
	}
}

private func toCamelCase(screamingSnake: some StringProtocol) -> String {
	screamingSnake.lowercased().replacing(#/_(\w)/#) { match in
		match.output.1.uppercased()
	}
}

struct FieldKeys: Sequence, IteratorProtocol {
	static let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	
	// digits of the current base-52 number, adding more as needed
	var digits = [0]
	
	mutating func next() -> String? {
		defer { advance() }
		return String(digits.reversed().lazy.map { Self.alphabet[$0] })
	}
	
	private mutating func advance() {
		for index in digits.indices {
			digits[index] += 1
			if digits[index] == Self.alphabet.count {
				digits[index] = 0
			} else {
				return // no carry
			}
		}
		digits.append(0)
	}
}

// https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure/#Keywords-and-Punctuation
let keywords: Set<String> = .init("""
associatedtype, class, deinit, enum, extension, fileprivate, func, import, init, inout, internal, let, open, operator, private, precedencegroup, protocol, public, rethrows, static, struct, subscript, typealias, var
break, case, catch, continue, default, defer, do, else, fallthrough, for, guard, if, in, repeat, return, throw, switch, where, while
Any, as, await, catch, false, is, nil, rethrows, self, Self, super, throw, throws, true, try
""".components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))

extension String {
	var escapedIfNeeded: String {
		keywords.contains(self) ? "`\(self)`" : self
	}
}

let generator = CodeGenerator()

generator.write("import GraphQLBuilder")

extension TypeReference {
	var requiresSelection: Bool {
		if let ofType {
			return ofType.requiresSelection
		} else {
			switch kind {
			case .scalar, .enum:
				return false
			default:
				return true
			}
		}
	}
}

for type in schema.types {
	generator.writeCode(for: type)
}

print()
//print(code)
try generator.code.write(toFile: "Schema.swift", atomically: false, encoding: .utf8)
