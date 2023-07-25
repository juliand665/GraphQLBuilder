import XCTest
@testable import GraphQLBuilder

final class GraphQLBuilderTests: XCTestCase {
    func testExample() throws {
		//print(\Foo.bar.count === (\Foo.bar)[keyPath: \String.count])
		print(#stringify(3 + 4))
    }
}

struct Foo {
	var bar: String
}
