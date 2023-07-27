import Foundation
import CodeGenHelpers

public protocol DataSource {
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar
	func object<Object: GraphQLDecodable>(access: FieldAccess) -> Object
}

public struct GraphQLQuery<Query: GraphQLObject, Output> {
	let get: (Query) throws -> Output
	public let queryCode: String
	let tracker = FieldTracker()
	let variables: [Variable]
	
	public init(_ get: @escaping (Query) throws -> Output) rethrows {
		self.get = get
		
		_ = try get(.init(source: tracker))
		let (selectionCode, variables) = tracker.generateCode()
		self.variables = variables
		
		let query = CodeGenerator()
		query.write("query", terminator: "")
		if !variables.isEmpty {
			query.write("(")
			query.indent {
				for v in variables {
					query.write("$\(v.key): \(v.type),")
				}
			}
			query.write(")", terminator: "")
		}
		query.writeBlock("") {
			query.write(selectionCode.dropLast()) // drop trailing newline
		}
		self.queryCode = query.code
	}
	
	public func makeRequest() -> GraphQLRequest {
		.init(query: queryCode, variables: variables)
	}
}

struct Variable {
	var key: String
	var type: String
	var value: any Encodable
}

extension FieldTracker {
	func generateCode() -> (selection: String, variables: [Variable]) {
		let selection = CodeGenerator()
		let variables = VariableStorage()
		selection.writeInputs(of: self, variables: variables)
		return (selection.code, variables.variables)
	}
}

private final class VariableStorage {
	private(set) var variables: [Variable] = []
	private var keys = FieldKeys()
	
	func register(_ argument: FieldAccess.Argument) -> String {
		let key = keys.nextKey()
		variables.append(.init(key: key, type: argument.type, value: argument.value))
		return key
	}
}

extension CodeGenerator {
	fileprivate func writeInputs(of tracker: FieldTracker, variables: VariableStorage) {
		for (access, inner) in tracker.accesses.values {
			let args = access.args
				.lazy
				.map { arg in "\(arg.name): $\(variables.register(arg))" }
				.joined(separator: ", ")
			let argClause = args.isEmpty ? "" : "(\(args))"
			let openBrace = inner == nil ? "" : " {"
			write("\(access.key): \(access.field)\(argClause)\(openBrace)")
			if let inner {
				indent {
					writeInputs(of: inner, variables: variables)
				}
				write("}")
			}
		}
	}
	
	func writeBlock(_ header: some StringProtocol, contents: () -> Void) {
		write("\(header) {")
		indent(contents)
		write("}")
	}
}

public struct GraphQLRequest: Encodable {
	var query: String
	var variables: [Variable] = []
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(query, forKey: .query)
		var varsContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .variables)
		for variable in variables {
			try varsContainer.encode(variable.value, forKey: .init(variable.key))
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case query
		case variables
	}
}

extension GraphQLQuery {
	public func decodeOutput(from data: Data, using decoder: JSONDecoder? = nil) throws -> Output {
		try (decoder ?? .init())
			.backportedDecode(Response.self, from: data, configuration: self).output
	}
	
	struct Response: DecodableWithConfiguration {
		var output: Output
		
		init(from decoder: Decoder, configuration: GraphQLQuery) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			if let errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors) {
				throw GraphQLErrors(errors: errors)
			} else {
				let query = try container.decode(Query.self, forKey: .data, configuration: configuration.tracker)
				output = try configuration.get(query)
			}
		}
		
		private enum CodingKeys: CodingKey {
			case data
			case errors
		}
	}
}

struct GraphQLDecoder: DataSource {
	let tracker: FieldTracker
	let container: KeyedDecodingContainer<StringKey>
	
	// TODO: error handling lol
	
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		try! container.decode(Scalar.self, forKey: .init(access.key))
	}
	
	func object<Object: GraphQLDecodable>(access: FieldAccess) -> Object {
		try! container.decode(
			Object.self, forKey: .init(access.key),
			configuration: tracker.accesses[access.key]!.inner!
		)
	}
}

struct StringKey: CodingKey {
	var stringValue: String
	
	var intValue: Int? { nil }
	
	init(_ string: String) {
		self.stringValue = string
	}
	
	init?(stringValue: String) {
		self.init(stringValue)
	}
	
	init?(intValue: Int) {
		fatalError()
	}
}

// TODO: @inlinable what makes sense
