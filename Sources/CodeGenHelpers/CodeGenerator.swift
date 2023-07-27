public final class CodeGenerator {
	@inlinable
	public static func generate(running block: (CodeGenerator) -> Void) -> String {
		let generator = Self()
		block(generator)
		return generator.getCode()
	}
	
	@usableFromInline let defaultIndent: String
	@usableFromInline var code = ""
	
	@usableFromInline var isStartingMultilineBlock = false
	
	@usableFromInline
	var needsIndent: Bool {
		code.isEmpty || code.last == "\n"
	}
	
	@inlinable
	public func getCode() -> String { code }
	
	public init(defaultIndent: String = "\t") {
		self.defaultIndent = defaultIndent
	}
	
	@usableFromInline var indentation = ""
	@inlinable
	public func indent(by change: String? = nil, _ block: () -> Void) {
		let old = indentation
		indentation += change ?? defaultIndent
		block()
		indentation = old
	}
	
	@inlinable
	public func newLine() {
		indentIfNeeded()
		code += "\n"
	}
	
	@inlinable
	public func writeLine(_ line: some StringProtocol) {
		indentIfNeeded()
		code += line
		code += "\n"
	}
	
	@inlinable
	public func writeLines(of part: some StringProtocol) {
		part.split(separator: "\n", omittingEmptySubsequences: false)
			.forEach(writeLine)
	}
	
	@usableFromInline
	func indentIfNeeded() {
		if isStartingMultilineBlock {
			isStartingMultilineBlock = false
			newLine()
		}
		if needsIndent {
			code += indentation
		}
	}
	
	/// no terminator
	@inlinable
	public func writePart(_ part: some StringProtocol) {
		indentIfNeeded()
		code += part
	}
	
	@inlinable
	public func writeMultiline(_ doWrite: () -> Void) {
		isStartingMultilineBlock = !needsIndent // start a new line if anything wants to write
		indent(doWrite)
		isStartingMultilineBlock = false // no new line if nothing wrote
	}
	
	@inlinable
	public func writeBlock(_ prefix: String = "", doWrite: () -> Void) {
		writePart("\(prefix) {")
		writeMultiline(doWrite)
		writeLine("}")
	}
	
	@inlinable
	public func writeItems<T>(in items: some Collection<T>, separator: String, as write: (T) -> Void) {
		for (index, item) in items.enumerated() {
			write(item)
			if index < items.count - 1 {
				writePart(separator)
			}
		}
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

extension DefaultStringInterpolation {
	@inlinable
	public mutating func appendInterpolation(quoting text: String) {
		appendLiteral(#""\#(text)""#)
	}
}
