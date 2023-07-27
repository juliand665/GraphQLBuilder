//import Foundation

public final class CodeGenerator {
	@usableFromInline
	let defaultIndent: String
	public private(set) var code = ""
	
	public init(defaultIndent: String = "\t") {
		self.defaultIndent = defaultIndent
	}
	
	@usableFromInline
	var indentation = ""
	@inlinable
	public func indent(by change: String? = nil, _ block: () -> Void) {
		let old = indentation
		indentation += change ?? defaultIndent
		block()
		indentation = old
	}
	
	@inlinable
	public func write() { write("") }
	public func write(_ part: some StringProtocol, terminator: String = "\n") {
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
	
	@inlinable
	public func writeBlock(_ prefix: String = "", contents: () -> Void) {
		write("\(prefix) {")
		indent(contents)
		write("}")
	}
}

public struct FieldKeys: Sequence, IteratorProtocol {
	@usableFromInline
	static let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	
	// digits of the current base-52 number, adding more as needed
	@usableFromInline
	private(set) var digits = [0]
	
	public init() {}
	
	@inlinable
	public mutating func next() -> String? {
		nextKey()
	}
	
	@inlinable
	public mutating func nextKey() -> String {
		defer { advance() }
		return String(digits.reversed().lazy.map { Self.alphabet[$0] })
	}
	
	@usableFromInline
	mutating func advance() {
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
