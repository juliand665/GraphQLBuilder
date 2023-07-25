public protocol InputValue: Encodable {}

public protocol GraphQLScalar: InputValue {
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

extension Array: GraphQLObject where Element: GraphQLObject {
	public static func mocked(tracker: FieldTracker) -> Self {
		[.mocked(tracker: tracker)] // a single value to make sure related code paths are used
	}
	
	public init(source: any DataSource) {
		// FIXME: elements
		fatalError()
	}
}

public protocol GraphQLObject {
	static func mocked(tracker: FieldTracker) -> Self
	init(source: any DataSource)
}

public extension GraphQLObject {
	static func mocked(tracker: FieldTracker) -> Self { .init(source: tracker) }
}

public protocol DataSource {
	func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar
	func object<Object: GraphQLObject>(access: FieldAccess) -> Object
}

public final class FieldTracker: DataSource {
	var accesses: [(access: FieldAccess, inner: FieldTracker?)] = []
	
	public func scalar<Scalar: GraphQLScalar>(access: FieldAccess) -> Scalar {
		accesses.append((access, inner: nil))
		return .mocked
	}
	
	public func object<Object: GraphQLObject>(access: FieldAccess) -> Object {
		let tracker = Self()
		accesses.append((access, inner: tracker))
		return .mocked(tracker: tracker)
	}
}

public struct FieldAccess {
	var key: String
	var field: String
	var args: [Argument] = []
	
	public init(key: String, field: String, args: [Argument] = []) {
		self.key = key
		self.field = field
		self.args = args
	}
	
	public struct Argument {
		var name: String
		var type: String
		var value: any InputValue
		
		public init(name: String, type: String, value: any InputValue) {
			self.name = name
			self.type = type
			self.value = value
		}
	}
}

/*
public enum Argument: CustomStringConvertible {
	case string(String)
	case int(Int)
	case double(Double)
	case bool(Bool)
	case id(String)
	//TODO: arbitrary encodable values
	//case other(any InputObject)
	// TODO: custom scalars?
	
	public var description: String {
		switch self {
		case .string(let string), .id(let string):
			return #""\#(string)""#
		case .int(let int):
			return "\(int)"
		case .double(let double):
			return "\(double)"
		case .bool(let bool):
			return "\(bool)"
		}
	}
}
*/

public struct GraphQLQuery<Query: GraphQLObject, Output> {
	let get: (Query) throws -> Output
	public let queryCode: String
	let variables: [Variable]
	
	public init(_ get: @escaping (Query) throws -> Output) rethrows {
		self.get = get
		
		let tracker = FieldTracker()
		_ = try get(.init(source: tracker))
		
		let querySelection = CodeGenerator()
		let variables = VariableStorage()
		querySelection.writeInputs(of: tracker, variables: variables)
		self.variables = variables.variables
		
		let queryCode = CodeGenerator()
		// TODO: multiline if non-empty
		let variableDefs = variables.variables
			.lazy
			.map { "$\($0.key): \($0.type)" }
			.joined(separator: ", ")
		queryCode.writeBlock("query(\(variableDefs))") {
			queryCode.write(querySelection.code.dropLast()) // drop trailing newline
		}
		self.queryCode = queryCode.code
	}
	
	public func makeRequest() -> Request {
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
		for (access, inner) in tracker.accesses {
			let args = access.args
				.lazy
				.map {
					let key = variables.register($0)
					return "\($0.name): $\(key)"
				}
				.joined(separator: ", ")
			// TODO: multiline if non-empty
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
			code += indentation
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

public struct Request: Encodable {
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
