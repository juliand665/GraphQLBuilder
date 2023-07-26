import Foundation

public protocol InputValue: Encodable {}

public protocol GraphQLScalar: InputValue, Decodable {
	static var mocked: Self { get }
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

extension Array: InputValue where Element: InputValue {}

extension Array: GraphQLScalar where Element: GraphQLScalar {
	public static var mocked: Self { [.mocked] }
}

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

extension StringID: GraphQLScalar {
	public static let mocked = Self(rawValue: "<mocked>")
}

extension GraphQLScalar where Self: CaseIterable {
	public static var mocked: Self { allCases.first! }
}

public protocol GraphQLValue: DecodableWithConfiguration where DecodingConfiguration == FieldTracker {
	static func mocked(tracker: FieldTracker) -> Self
}

public protocol GraphQLObject: GraphQLValue {
	init(source: any DataSource)
}

public extension GraphQLObject {
	init(from decoder: Decoder, configuration: FieldTracker) throws {
		self.init(source: DecodingDataSource(
			tracker: configuration,
			container: try decoder.container(keyedBy: StringKey.self)
		))
	}
}

public extension GraphQLObject {
	static func mocked(tracker: FieldTracker) -> Self {
		.init(source: tracker)
	}
}

extension Array: GraphQLValue where Element: GraphQLValue {
	public static func mocked(tracker: FieldTracker) -> Self {
		[.mocked(tracker: tracker)] // a single value to make sure related code paths are used
	}
}

extension Optional: GraphQLValue where Wrapped: GraphQLValue {
	public static func mocked(tracker: FieldTracker) -> Optional<Wrapped> {
		Wrapped.mocked(tracker: tracker)
	}
}

public protocol DataSource {
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar
	func object<Object: GraphQLValue>(access: FieldAccess) -> Object
}

public final class FieldTracker: DataSource {
	typealias TrackedAccess = (access: FieldAccess, inner: FieldTracker?)
	
	var accesses: [String: TrackedAccess] = [:]
	
	// TODO: enable multiple requests of the same property (e.g. with different args)
	
	private func registerAccess(_ access: FieldAccess, inner: FieldTracker? = nil, forKey key: String) {
		assert(accesses[key] == nil, "already making a request for key \(access.field) as \(key)")
		accesses[key] = (access, inner)
	}
	
	public func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		registerAccess(access, forKey: access.key)
		return .mocked
	}
	
	public func object<Object: GraphQLValue>(access: FieldAccess) -> Object {
		let tracker = Self()
		registerAccess(access, inner: tracker, forKey: access.key)
		return .mocked(tracker: tracker)
	}
}

public struct FieldAccess {
	var key: String
	var field: String
	var args: [Argument] = []
	
	public init(key: String, field: String, args: [Argument?] = []) {
		self.key = key
		self.field = field
		self.args = args.compactMap { $0 }
	}
	
	public struct Argument {
		var name: String
		var type: String
		var value: any InputValue
		
		public init?(name: String, type: String, value: (any InputValue)?) {
			guard let value else { return nil }
			self.name = name
			self.type = type
			self.value = value
		}
	}
}

public struct GraphQLQuery<Query: GraphQLObject, Output> {
	let get: (Query) throws -> Output
	public let queryCode: String
	let tracker = FieldTracker()
	let variables: [Variable]
	
	public init(_ get: @escaping (Query) throws -> Output) rethrows {
		self.get = get
		
		_ = try get(.init(source: tracker))
		
		let querySelection = CodeGenerator()
		let variables = VariableStorage()
		querySelection.writeInputs(of: tracker, variables: variables)
		self.variables = variables.variables
		
		let queryCode = CodeGenerator()
		// TODO: multiline if non-empty?
		let variableDefs = variables.variables
			.lazy
			.map { "$\($0.key): \($0.type)" }
			.joined(separator: ", ")
		queryCode.writeBlock("query(\(variableDefs))") {
			queryCode.write(querySelection.code.dropLast()) // drop trailing newline
		}
		self.queryCode = queryCode.code
	}
	
	public func makeRequest() -> GraphQLRequest {
		.init(query: queryCode, variables: variables)
	}
}

final class VariableStorage {
	private(set) var variables: [Variable] = []
	private var keys = FieldKeys()
	
	func register(_ argument: FieldAccess.Argument) -> String {
		let key = keys.nextKey()
		variables.append(.init(key: key, type: argument.type, value: argument.value))
		return key
	}
}

struct Variable {
	var key: String
	var type: String
	var value: any Encodable
}

extension CodeGenerator {
	func writeInputs(of tracker: FieldTracker, variables: VariableStorage) {
		for (access, inner) in tracker.accesses.values {
			let args = access.args
				.lazy
				.map {
					let key = variables.register($0)
					return "\($0.name): $\(key)"
				}
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

// TODO: share

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

struct FieldKeys: Sequence, IteratorProtocol {
	static let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	
	// digits of the current base-52 number, adding more as needed
	var digits = [0]
	
	mutating func next() -> String? {
		nextKey()
	}
	
	mutating func nextKey() -> String {
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
	public func decodeOutput(from data: Data, using decoder: JSONDecoder?) throws -> Output {
		let decoder = decoder ?? .init()
		return try decoder.runDecoder(on: data) { decoder in
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let query = Query(source: DecodingDataSource(
				tracker: tracker,
				container: try container.nestedContainer(keyedBy: StringKey.self, forKey: .data)
			))
			return try get(query)
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case data
		case errors // TODO: handle
	}
}

struct DecodingDataSource: DataSource {
	let tracker: FieldTracker
	let container: KeyedDecodingContainer<StringKey>
	
	// TODO: error handling lol
	
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		try! container.decode(Scalar.self, forKey: .init(access.key))
	}
	
	func object<Object: GraphQLValue>(access: FieldAccess) -> Object {
		let inner = tracker.accesses[access.key]!.inner!
		return try! container.decode(Object.self, forKey: .init(access.key), configuration: inner)
	}
}

// the right tool for this job would absolutely be DecodableWithConfiguration, but Apple only added that in 2023 (iOS 17, macOS 14), so we'd rather not require it. instead we'll use the ugly classic userInfo hack
extension JSONDecoder {
	private static let key = CodingUserInfoKey(rawValue: UUID().uuidString)!
	
	func runDecoder<T>(on data: Data, run block: (Decoder) throws -> T) throws -> T { // can't make this generic because of the nested type
		try withoutActuallyEscaping(block) { block in
			userInfo[Self.key] = block
			defer { userInfo[Self.key] = nil }
			return try decode(Content<T>.self, from: data).value
		}
	}
	
	private struct Content<T>: Decodable {
		var value: T
		
		init(from decoder: Decoder) throws {
			let block = decoder.userInfo[key]! as! (Decoder) throws -> T
			value = try block(decoder)
		}
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
