import Foundation
import CodeGenHelpers

extension FieldTracker {
	func generateCode() -> (selection: String, variables: [Variable]) {
		let variables = VariableStorage()
		let selection = CodeGenerator.generate {
			$0.writeInputs(of: self, variables: variables)
		}
		return (selection, variables.variables)
	}
}

private final class VariableStorage {
	private(set) var variables: [Variable] = []
	private var keys = FieldKeys()
	
	func register(_ argument: FieldAccess.Argument) -> String {
		let key = keys.nextKey()
		variables.append(.init(key: key, type: argument.type, value: argument.value))
		return key
	}
}

extension CodeGenerator {
	fileprivate func writeInputs(of tracker: FieldTracker, variables: VariableStorage) {
		if !tracker.casts.isEmpty {
			writeLine("_: __typename")
		}
		for access in tracker.accesses {
			writePart("\(access.key): \(access.access.field)")
			if !access.access.args.isEmpty {
				let args = access.access.args
					.lazy
					.map { arg in "\(arg.name): $\(variables.register(arg))" }
					.joined(separator: ", ")
				writePart("(\(args))")
			}
			if let inner = access.inner {
				writeBlock {
					writeInputs(of: inner, variables: variables)
				}
			} else {
				newLine()
			}
		}
		for cast in tracker.casts {
			writeBlock("... on \(cast.typeName)") {
				writeInputs(of: cast.inner, variables: variables)
			}
		}
	}
	
	func writeQuery(_ selectionCode: String, variables: [Variable]) {
		writePart("query")
		if !variables.isEmpty {
			writeLine("(")
			writeMultiline {
				for v in variables {
					writeLine("$\(v.key): \(v.type),")
				}
			}
			writePart(")")
		}
		writeBlock {
			writeLines(of: selectionCode.dropLast()) // drop trailing newline
		}
	}
}
