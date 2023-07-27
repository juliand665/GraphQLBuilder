import Foundation
import GraphQLBuilder

let testQuery = GraphQLQuery<Query, _> {
	let countries = $0.countries()
		.lazy
		.map { "- \($0.emoji()) \($0.name(lang: "de"))" }
		.joined(separator: "\n")
	
	let continents = $0.continents(
		filter: .init(code: .init(nin: ["OC", "SA"]))
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
