import Foundation

public final class FieldTracker: DataSource {
	@usableFromInline
	typealias TrackedAccess = (access: FieldAccess, inner: FieldTracker?)
	
	@usableFromInline var accesses: [TrackedAccess] = []
	
	@usableFromInline init() {}
	
	@inlinable
	public func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		accesses.append((access, inner: nil))
		return .mocked
	}
	
	@inlinable
	public func object<Object: GraphQLDecodable>(access: FieldAccess) -> Object {
		let tracker = Self()
		accesses.append((access, inner: tracker))
		return .mocked(tracker: tracker)
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
