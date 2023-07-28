import Foundation
import CodeGenHelpers

public extension GraphQLObject {
	init(from decoder: Decoder, configuration: FieldTracker) throws {
		self.init(source: try GraphQLDecoder(
			tracker: configuration,
			container: decoder.container(keyedBy: StringKey.self)
		))
	}
}

private final class GraphQLDecoder: DataSource {
	let tracker: FieldTracker
	let container: KeyedDecodingContainer<StringKey>
	var index = 0
	var castIndex = 0
	
	var typeName: String
	
	init(tracker: FieldTracker, container: KeyedDecodingContainer<StringKey>) throws {
		self.tracker = tracker
		self.container = container
		self.typeName = try container.decode(String.self, forKey: .init("_"))
	}
	
	private func nextAccess() -> TrackedAccess {
		defer { index += 1 }
		return tracker.accesses[index]
	}
	
	private func nextCast() -> TrackedCast {
		defer { castIndex += 1 }
		return tracker.casts[index]
	}
	
	// relying on these functions always being called in the same order
	
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) throws -> Scalar {
		try container.decode(Scalar.self, forKey: .init(nextAccess().key))
	}
	
	func object<Object: GraphQLDecodable>(access: FieldAccess) throws -> Object {
		let access = nextAccess()
		return try container.decode(
			Object.self, forKey: .init(access.key),
			configuration: access.inner!
		)
	}
	
	func cast<T: GraphQLObject>(to typeName: String) throws -> T? {
		let cast = nextCast()
		guard typeName == self.typeName else { return nil }
		return .init(source: try Self(tracker: cast.inner, container: container))
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
