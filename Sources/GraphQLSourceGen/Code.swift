import Foundation
import CodeGenHelpers

extension CodeGenerator {
	func writeAsMultilineDocComment(_ part: (some StringProtocol)?) {
		guard let part else { return }
		writeLine("/**")
		writeLines(of: part)
		writeLine("*/")
	}
	
	func writeAsInlineDocComment(_ part: (some StringProtocol)?) {
		guard let part else { return }
		indent(by: "/// ") {
			writeLines(of: part)
		}
	}
	
	func writeCode(for type: TypeInfo) {
		guard type.kind != .scalar else { return } // handled outside
		guard !type.name.hasPrefix("__") else {
			log("skipping introspection type \(type.name)")
			return
		}
		// TODO: deprecation?
		if getCode().last != "{" {
			newLine()
		}
		writeAsMultilineDocComment(type.description)
		switch type.kind {
		case .object:
			writeObjectCode(for: type)
		case .interface:
			writeInterfaceCode(for: type)
		case .union:
			writeUnionCode(for: type)
		case .enum:
			writeEnumCode(for: type)
		case .inputObject:
			writeInputObjectCode(for: type)
		case .scalar:
			fatalError("already handled above")
		case .list, .nonNull:
			fatalError("attempting to generate code for type modifier")
		}
	}
	
	func writeObjectCode(for type: TypeInfo) {
		writeBlock("struct \(type.name): GraphQLObject") {
			writeDataSourceCode()
			
			for field in type.fields! {
				writeCode(for: field)
			}
		}
	}
	
	func writeInterfaceCode(for type: TypeInfo) {
		writeBlock("struct \(type.name): GraphQLInterface") {
			writeDataSourceCode()
			
			for field in type.fields! {
				writeCode(for: field)
			}
			
			for targetType in type.possibleTypes! {
				writeDowncastCode(for: targetType)
			}
			
			// TODO: allow downcasting to sub-interfaces?
		}
	}
	
	func writeUnionCode(for type: TypeInfo) {
		writeBlock("struct \(type.name): GraphQLUnion") {
			writeDataSourceCode()
			
			for targetType in type.possibleTypes! {
				writeDowncastCode(for: targetType)
			}
		}
	}
	
	func writeDataSourceCode() {
		writeLine("private var _source: any DataSource")
		newLine()
		writeLine("init(source: any DataSource) { self._source = source }")
	}
	
	func writeDowncastCode(for targetType: TypeReference) {
		newLine()
		let name = targetType.name!
		writeBlock("func as\(name)() throws -> \(name)?") {
			writeLine("try _source.cast(to: \(quoting: name))")
		}
	}
	
	func writeCode(for field: Field) {
		newLine()
		writeAsInlineDocComment(field.description)
		for arg in field.args {
			guard let description = arg.description else { continue }
			let defaultPart = arg.defaultValue.map { " (Default: \($0))" } ?? ""
			writeAsInlineDocComment("- Parameter \(arg.name): \(description)\(defaultPart)")
		}
		writePart("func \(escaping: field.name)(")
		writeItems(in: field.args, separator: ", ") { arg in
			writePart("\(arg.name): \(arg.type.swiftName)")
			if !arg.requiresValue {
				writePart(" = nil")
			}
		}
		writeBlock(") throws -> \(field.type.swiftName)") {
			let function = field.type.requiresSelection ? "object" : "scalar"
			writePart("try _source.\(function)(access: .init(field: \(quoting: field.name), args: [")
			writeMultiline {
				for arg in field.args {
					writeLine(".init(name: \(quoting: arg.name), type: \(quoting: arg.type.graphQLName), value: \(arg.name)),")
				}
			}
			writeLine("]))")
		}
	}
	
	func writeEnumCode(for type: TypeInfo) {
		writeBlock("enum \(type.name): String, GraphQLScalar, CaseIterable") {
			for value in type.enumValues! {
				writeAsInlineDocComment(value.description)
				if value.name.contains(where: \.isLowercase) {
					writeLine("case \(escaping: value.name)")
				} else {
					let camelCased = toCamelCase(screamingSnake: value.name)
					writeLine("case \(escaping: camelCased) = \(quoting: value.name)")
				}
			}
		}
	}
	
	func writeInputObjectCode(for type: TypeInfo) {
		writeBlock("struct \(type.name): InputValue") {
			for field in type.inputFields! {
				writeAsInlineDocComment(field.description)
				let type = field.type.swiftName
				if let defaultValue = field.defaultValue {
					writeAsInlineDocComment("Default Value: \(defaultValue)")
					writeLine("var \(escaping: field.name): \(type) = nil")
				} else {
					writeLine("var \(escaping: field.name): \(type)")
				}
			}
		}
	}
}

let builtinScalars: [String: String] = [
	"Boolean": "Bool",
	"Int": "Int",
	"Float": "Double",
	"String": "String",
	"ID": "StringID",
]

extension TypeReference {
	var swiftName: String {
		let (typeName, nonNull) = info()
		return nonNull ? typeName : "\(typeName)?"
	}
	
	var graphQLName: String {
		switch kind {
		case .nonNull:
			return "\(ofType!.graphQLName)!"
		case .list:
			return "[\(ofType!.graphQLName)]"
		default:
			return name!
		}
	}
	
	private func info() -> (name: String, nonNull: Bool) {
		var typeName: String
		switch kind {
		case .nonNull:
			return (name: ofType!.info().name, nonNull: true)
		case .list:
			typeName = "[\(ofType!.swiftName)]"
		case .scalar:
			typeName = builtinScalars[name!] ?? name!
		default:
			typeName = name!
		}
		return (name: typeName, nonNull: false)
	}
	
	var requiresSelection: Bool {
		if let ofType {
			return ofType.requiresSelection
		} else {
			switch kind {
			case .scalar, .enum:
				return false
			default:
				return true
			}
		}
	}
}

extension InputValue {
	var requiresValue: Bool {
		defaultValue == nil && type.kind == .nonNull
	}
}

private func toCamelCase(screamingSnake: some StringProtocol) -> String {
	screamingSnake.lowercased().replacing(#/_(\w)/#) { match in
		match.output.1.uppercased()
	}
}

// https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure/#Keywords-and-Punctuation
private let keywords: Set<String> = .init("""
associatedtype, class, deinit, enum, extension, fileprivate, func, import, init, inout, internal, let, open, operator, private, precedencegroup, protocol, public, rethrows, static, struct, subscript, typealias, var
break, case, catch, continue, default, defer, do, else, fallthrough, for, guard, if, in, repeat, return, throw, switch, where, while
Any, as, await, catch, false, is, nil, rethrows, self, Self, super, throw, throws, true, try
""".components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters)))

extension DefaultStringInterpolation {
	mutating func appendInterpolation(escaping text: String) {
		appendLiteral(keywords.contains(text) ? "`\(text)`" : text)
	}
}
