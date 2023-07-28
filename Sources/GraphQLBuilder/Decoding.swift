import Foundation
import CodeGenHelpers

public extension GraphQLObject {
	init(from decoder: Decoder, configuration: FieldTracker) throws {
		self.init(source: GraphQLDecoder(
			tracker: configuration,
			container: try decoder.container(keyedBy: StringKey.self)
		))
	}
}

private final class GraphQLDecoder: DataSource {
	let tracker: FieldTracker
	let container: KeyedDecodingContainer<StringKey>
	var keys = FieldKeys()
	var index = -1
	
	init(tracker: FieldTracker, container: KeyedDecodingContainer<StringKey>) {
		self.tracker = tracker
		self.container = container
	}
	
	private func nextKey() -> StringKey {
		index += 1
		return .init(keys.nextKey())
	}
	
	// relying on these functions always being called in the same order
	
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) throws -> Scalar {
		try container.decode(Scalar.self, forKey: nextKey())
	}
	
	func object<Object: GraphQLDecodable>(access: FieldAccess) throws -> Object {
		try container.decode(
			Object.self, forKey: nextKey(),
			configuration: tracker.accesses[index].inner!
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
