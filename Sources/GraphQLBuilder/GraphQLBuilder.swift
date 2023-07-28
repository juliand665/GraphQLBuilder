import Foundation
import CodeGenHelpers

public protocol DataSource {
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) throws -> Scalar
	func object<Object: GraphQLDecodable>(access: FieldAccess) throws -> Object
	func cast<T: GraphQLObject>(to typeName: String) throws -> T?
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
		
		self.queryCode = CodeGenerator.generate {
			$0.writeQuery(selectionCode, variables: variables)
		}
	}
	
	public func makeRequest() -> some Encodable {
		GraphQLRequest(query: queryCode, variables: variables)
	}
	
	public func decodeOutput(from data: Data, using decoder: JSONDecoder? = nil) throws -> Output {
		try (decoder ?? .init())
			.backportedDecode(Response.self, from: data, configuration: self).output
	}
}

struct Variable {
	var key: String
	var type: String
	var value: any Encodable
}

struct GraphQLRequest: Encodable {
	var query: String
	var variables: [Variable] = []
	
	func encode(to encoder: Encoder) throws {
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
	private struct Response: DecodableWithConfiguration {
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

// TODO: @inlinable what makes sense
