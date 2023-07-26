import Foundation
import GraphQLBuilder
/*
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
*/

let testQuery = GraphQLQuery<Query, _> {
	let countries = $0.countries()
		.lazy
		.map { "- \($0.emoji()) \($0.name(lang: "de"))" }
		.joined(separator: "\n")
	
	let continents = $0.continents(
		filter: .init(code: .init(nin: ["OC", "NA"]))
	).map {
		let countries = $0.countries()
			.lazy
			.map { $0.name() }
			.filter { $0.first == "A" }
			.joined(separator: ", ")
		return "\($0.name())'s A-countries: \(countries)"
	}
	
	return (countries, continents)
}

print(testQuery.queryCode)

let request = testQuery.makeRequest()
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let encoded = try! encoder.encode(request)
print(String(bytes: encoded, encoding: .utf8)!)

var rawRequest = URLRequest(url: URL(string: "https://countries.trevorblades.com/graphql")!)
rawRequest.httpBody = encoded
rawRequest.httpMethod = "POST"
rawRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

let (rawResponse, _) = try! await URLSession.shared.data(for: rawRequest)
let (countries, continents) = try testQuery.decodeOutput(from: rawResponse, using: JSONDecoder())
print(countries)
print(continents.joined(separator: "\n"))
