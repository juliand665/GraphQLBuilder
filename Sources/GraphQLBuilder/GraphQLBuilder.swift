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
	
	/// Creates an `Encodable` representation of this request for sending as an HTTP request's body.
	public func makeRequest() -> some Encodable {
		GraphQLRequest(query: queryCode, variables: variables)
	}
	
	/// Prepares a ``URLRequest`` with the correct method, content type, and body for this request.
	public func encodeRequest(to request: inout URLRequest, using encoder: JSONEncoder? = nil) throws {
		request.httpMethod = "POST"
		request.httpBody = try (encoder ?? .init()).encode(makeRequest())
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
	}
	
	/// Parses received JSON output from the server's endpoint, gathering GraphQL errors into an instance of ``GraphQLErrors``.
	public func decodeOutput(from data: Data, using decoder: JSONDecoder? = nil) throws -> Output {
		do {
			return try (decoder ?? .init())
				.backportedDecode(Response.self, from: data, configuration: self).output
		} catch let error as DecodingError {
			switch error {
			case
				// this gets indented too far with leading-dot syntax
				DecodingError.typeMismatch(_, let context),
				DecodingError.valueNotFound(_, let context),
				DecodingError.keyNotFound(_, let context),
				DecodingError.dataCorrupted(let context):
				throw GraphQLDecodingError(translatedPath: translateCodingPath(context.codingPath.dropFirst()), error: error)
			@unknown default:
				throw error
			}
		}
	}
	
	func translateCodingPath(_ path: some Sequence<CodingKey>) -> String {
		var string = "\(Query.self)"
		var _tracker: FieldTracker? = self.tracker
		for key in path {
			if let int = key.intValue {
				string.append("[\(int)]")
			} else {
				guard let tracker = _tracker else {
					string.append("<unexpected field>...")
					break
				}
				
				var keyString = key.stringValue
				string.append(".")
				
				while let match = key.stringValue.wholeMatch(of: #/(\w+_)(\w+)/#) {
					let (_, keyPrefix, key) = match.output
					let cast = tracker.casts.first { $0.inner.keyPrefix == keyPrefix }
					guard let cast else {
						string.append("<unrecognized cast as \(keyPrefix)>...")
						break
					}
					string.append("cast(to: \(cast.typeName)).")
					keyString = String(key)
				}
				
				let access = tracker.accesses.first { $0.key == keyString }
				guard let access else {
					string.append("<unrecognized field \(keyString)>...")
					break
				}
				string.append(access.access.field)
				if !access.access.args.isEmpty {
					let args = access.access.args.lazy.map { "\($0.name):" }.joined()
					string.append("(\(args))")
				}
				_tracker = access.inner
			}
		}
		return string
	}
}

struct GraphQLDecodingError: Error {
	var translatedPath: String
	var error: DecodingError
}

public typealias URLRequest = Foundation.URLRequest

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
			if let errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors), !errors.isEmpty {
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
