import Foundation
import CodeGenHelpers

// TODO: figure out if all this inlining is helping

public final class FieldTracker: DataSource {
	@usableFromInline var accesses: [TrackedAccess] = []
	@usableFromInline var casts: [TrackedCast] = []
	
	@usableFromInline var keyPrefix: String
	@usableFromInline var keys = FieldKeys()
	@usableFromInline var castKeys = FieldKeys()
	
	@usableFromInline init(keyPrefix: String = "") {
		self.keyPrefix = keyPrefix
	}
	
	@inlinable
	public func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		accesses.append(.init(key: keyPrefix + keys.nextKey(), access: access, inner: nil))
		return .mocked
	}
	
	@inlinable
	public func object<Object: GraphQLDecodable>(access: FieldAccess) -> Object {
		let tracker = Self()
		accesses.append(.init(key: keyPrefix + keys.nextKey(), access: access, inner: tracker))
		return .mocked(tracker: tracker)
	}
	
	@inlinable
	public func cast<T: GraphQLObject>(to typeName: String) throws -> T? {
		let tracker = Self(keyPrefix: castKeys.nextKey() + "_")
		casts.append(.init(typeName: typeName, inner: tracker))
		return .mocked(tracker: tracker)
	}
}

@usableFromInline
struct TrackedAccess {
	var key: String
	var access: FieldAccess
	var inner: FieldTracker?
	
	@usableFromInline
	init(key: String, access: FieldAccess, inner: FieldTracker?) {
		self.key = key
		self.access = access
		self.inner = inner
	}
}

@usableFromInline
struct TrackedCast {
	var typeName: String
	var inner: FieldTracker
	
	@usableFromInline
	init(typeName: String, inner: FieldTracker) {
		self.typeName = typeName
		self.inner = inner
	}
}

public struct FieldAccess {
	@usableFromInline var field: String
	@usableFromInline var args: [Argument] = []
	
	@inlinable
	public init(field: String, args: [Argument?] = []) {
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
