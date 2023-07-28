import System

private struct FileDescriptorStream: TextOutputStream {
	let descriptor: FileDescriptor
	
	func write(_ string: String) {
		try! descriptor.writeAll(string.utf8)
	}
}

private var standardError = FileDescriptorStream(descriptor: .standardError)

func log(_ string: some StringProtocol) {
	print(string, to: &standardError)
}
