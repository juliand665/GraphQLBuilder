import Foundation

public final class FieldTracker: DataSource {
	@usableFromInline
	typealias TrackedAccess = (access: FieldAccess, inner: FieldTracker?)
	
	@usableFromInline var accesses: [String: TrackedAccess] = [:]
	
	@usableFromInline init() {}
	
	// TODO: enable multiple requests of the same property (e.g. with different args)
	
	@usableFromInline
	func registerAccess(_ access: FieldAccess, inner: FieldTracker? = nil, forKey key: String) {
		assert(accesses[key] == nil, "already making a request for key \(access.field) as \(key)")
		accesses[key] = (access, inner)
	}
	
	@inlinable
	public func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		registerAccess(access, forKey: access.key)
		return .mocked
	}
	
	@inlinable
	public func object<Object: GraphQLDecodable>(access: FieldAccess) -> Object {
		let tracker = Self()
		registerAccess(access, inner: tracker, forKey: access.key)
		return .mocked(tracker: tracker)
	}
}

public struct FieldAccess {
	@usableFromInline var key: String
	@usableFromInline var field: String
	@usableFromInline var args: [Argument] = []
	
	@inlinable
	public init(key: String, field: String, args: [Argument?] = []) {
		self.key = key
		self.field = field
		self.args = args.compactMap { $0 }
	}
	
	public struct Argument {
		@usableFromInline var name: String
		@usableFromInline var type: String
		@usableFromInline var value: any InputValue
		
		@inlinable
		public init?(name: String, type: String, value: (any InputValue)?) {
			guard let value else { return nil }
			self.name = name
			self.type = type
			self.value = value
		}
	}
}
