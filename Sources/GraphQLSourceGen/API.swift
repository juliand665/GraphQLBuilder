import Foundation

struct Request: Encodable {
	var query: String
	var variables: [String: Never] = [:]
}

struct SchemaResponse: Decodable {
	var data: Body?
	var errors: [GraphQLError]?
	
	struct Body: Decodable {
		var schema: Schema
	}
}

struct GraphQLError: Decodable, Error {
	var message: String
}
