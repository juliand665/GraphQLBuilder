import Foundation

/// Represents GraphQL's `ID` type.
public struct StringID {
	public var rawValue: String
}

extension StringID: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.rawValue = try container.decode(String.self)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

/// A value that can be used as argument to a field access in a query.
public protocol InputValue: Encodable {}

/// The leaves of the GraphQL type system—you do not define a selection of fields for these, and they can be passed as input values as well.
public protocol GraphQLScalar: InputValue, Decodable {
	static var mocked: Self { get }
}

public protocol GraphQLDecodable: DecodableWithConfiguration where DecodingConfiguration == FieldTracker {
	static func mocked(tracker: FieldTracker) -> Self
}

public protocol GraphQLObject: GraphQLDecodable {
	init(source: any DataSource)
}

public protocol GraphQLInterface: GraphQLObject {}
public protocol GraphQLUnion: GraphQLObject {}

public extension GraphQLObject {
	static func mocked(tracker: FieldTracker) -> Self {
		.init(source: tracker)
	}
}

extension String: GraphQLScalar {
	public static let mocked = "<mocked>"
}

extension Int: GraphQLScalar {
	public static let mocked = 0
}

extension Double: GraphQLScalar {
	public static let mocked = 0.0
}

extension Bool: GraphQLScalar {
	public static let mocked = false
}

extension StringID: GraphQLScalar {
	public static let mocked = Self(rawValue: "<mocked>")
}

extension GraphQLScalar where Self: CaseIterable {
	public static var mocked: Self { allCases.first! }
}

extension Array: InputValue where Element: InputValue {}
extension Optional: InputValue where Wrapped: InputValue {}

extension Array: GraphQLScalar where Element: GraphQLScalar {
	public static var mocked: Self { [.mocked] }
}

extension Optional: GraphQLScalar where Wrapped: GraphQLScalar {
	public static var mocked: Self { Wrapped.mocked }
}

extension Array: GraphQLDecodable where Element: GraphQLDecodable {
	public static func mocked(tracker: FieldTracker) -> Self {
		[.mocked(tracker: tracker)] // a single value to make sure related code paths are used
	}
}

extension Optional: GraphQLDecodable where Wrapped: GraphQLDecodable {
	public static func mocked(tracker: FieldTracker) -> Optional<Wrapped> {
		Wrapped.mocked(tracker: tracker)
	}
}

public struct GraphQLErrors: Error {
	public let errors: [GraphQLError]
}

public struct GraphQLError: Decodable, Error {
	public var message: String
	public var path: [PathSegment]?
	public var locations: [Location]?
	
	public struct Location: Decodable {
		var line, column: Int
	}
	
	public enum PathSegment: Decodable {
		case field(String)
		case index(Int)
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			if let index = try? container.decode(Int.self) {
				self = .index(index)
			} else {
				self = .field(try container.decode(String.self))
			}
		}
	}
}
