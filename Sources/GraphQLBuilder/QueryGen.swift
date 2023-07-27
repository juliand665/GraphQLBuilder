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
		for (access, inner) in tracker.accesses.values {
			writePart("\(access.key): \(access.field)")
			if !access.args.isEmpty {
				let args = access.args
					.lazy
					.map { arg in "\(arg.name): $\(variables.register(arg))" }
					.joined(separator: ", ")
				writePart("(\(args))")
			}
			if let inner {
				writeBlock {
					writeInputs(of: inner, variables: variables)
				}
			} else {
				newLine()
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
