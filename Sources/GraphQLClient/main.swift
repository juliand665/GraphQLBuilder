import Foundation
import GraphQLBuilder

struct User: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) {
		self.source = source
	}
	
	func id() -> String {
		source.scalar(access: .init(key: "a", field: "id"))
	}
	
	func friends(minScore: Int = 0) -> [User] {
		source.object(access: .init(key: "b", field: "friends", args: [.init(name: "minScore", type: "Int", value: minScore)]))
	}
}

struct Query: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) {
		self.source = source
	}
	
	func user() -> User {
		source.object(access: .init(key: "a", field: "user"))
	}
}

let testQuery = GraphQLQuery<Query, _> {
	let user = $0.user()
	let friends = user.friends(minScore: 5).map { $0.id() }
	return "user \(user.id()) with \(friends.count) friends"
}

print(testQuery.queryCode)

let request = testQuery.makeRequest()
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let encoded = try! encoder.encode(request)
print(String(bytes: encoded, encoding: .utf8)!)
