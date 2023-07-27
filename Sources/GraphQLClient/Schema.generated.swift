import GraphQLBuilder

struct Continent: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func code() throws -> StringID {
		try source.scalar(access: .init(field: "code", args: []))
	}
	
	func countries() throws -> [Country] {
		try source.object(access: .init(field: "countries", args: []))
	}
	
	func name() throws -> String {
		try source.scalar(access: .init(field: "name", args: []))
	}
}

struct ContinentFilterInput: InputValue {
	var code: StringQueryOperatorInput?
}

struct Country: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func awsRegion() throws -> String {
		try source.scalar(access: .init(field: "awsRegion", args: []))
	}
	
	func capital() throws -> String? {
		try source.scalar(access: .init(field: "capital", args: []))
	}
	
	func code() throws -> StringID {
		try source.scalar(access: .init(field: "code", args: []))
	}
	
	func continent() throws -> Continent {
		try source.object(access: .init(field: "continent", args: []))
	}
	
	func currencies() throws -> [String] {
		try source.scalar(access: .init(field: "currencies", args: []))
	}
	
	func currency() throws -> String? {
		try source.scalar(access: .init(field: "currency", args: []))
	}
	
	func emoji() throws -> String {
		try source.scalar(access: .init(field: "emoji", args: []))
	}
	
	func emojiU() throws -> String {
		try source.scalar(access: .init(field: "emojiU", args: []))
	}
	
	func languages() throws -> [Language] {
		try source.object(access: .init(field: "languages", args: []))
	}
	
	func name(lang: String? = nil) throws -> String {
		try source.scalar(access: .init(field: "name", args: [
			.init(name: "lang", type: "String", value: lang),
		]))
	}
	
	func native() throws -> String {
		try source.scalar(access: .init(field: "native", args: []))
	}
	
	func phone() throws -> String {
		try source.scalar(access: .init(field: "phone", args: []))
	}
	
	func phones() throws -> [String] {
		try source.scalar(access: .init(field: "phones", args: []))
	}
	
	func states() throws -> [State] {
		try source.object(access: .init(field: "states", args: []))
	}
	
	func subdivisions() throws -> [Subdivision] {
		try source.object(access: .init(field: "subdivisions", args: []))
	}
}

struct CountryFilterInput: InputValue {
	var code: StringQueryOperatorInput?
	var continent: StringQueryOperatorInput?
	var currency: StringQueryOperatorInput?
}

struct Language: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func code() throws -> StringID {
		try source.scalar(access: .init(field: "code", args: []))
	}
	
	func name() throws -> String {
		try source.scalar(access: .init(field: "name", args: []))
	}
	
	func native() throws -> String {
		try source.scalar(access: .init(field: "native", args: []))
	}
	
	func rtl() throws -> Bool {
		try source.scalar(access: .init(field: "rtl", args: []))
	}
}

struct LanguageFilterInput: InputValue {
	var code: StringQueryOperatorInput?
}

struct Query: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func continent(code: StringID) throws -> Continent? {
		try source.object(access: .init(field: "continent", args: [
			.init(name: "code", type: "ID!", value: code),
		]))
	}
	
	func continents(filter: ContinentFilterInput? = nil) throws -> [Continent] {
		try source.object(access: .init(field: "continents", args: [
			.init(name: "filter", type: "ContinentFilterInput", value: filter),
		]))
	}
	
	func countries(filter: CountryFilterInput? = nil) throws -> [Country] {
		try source.object(access: .init(field: "countries", args: [
			.init(name: "filter", type: "CountryFilterInput", value: filter),
		]))
	}
	
	func country(code: StringID) throws -> Country? {
		try source.object(access: .init(field: "country", args: [
			.init(name: "code", type: "ID!", value: code),
		]))
	}
	
	func language(code: StringID) throws -> Language? {
		try source.object(access: .init(field: "language", args: [
			.init(name: "code", type: "ID!", value: code),
		]))
	}
	
	func languages(filter: LanguageFilterInput? = nil) throws -> [Language] {
		try source.object(access: .init(field: "languages", args: [
			.init(name: "filter", type: "LanguageFilterInput", value: filter),
		]))
	}
}

struct State: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func code() throws -> String? {
		try source.scalar(access: .init(field: "code", args: []))
	}
	
	func country() throws -> Country {
		try source.object(access: .init(field: "country", args: []))
	}
	
	func name() throws -> String {
		try source.scalar(access: .init(field: "name", args: []))
	}
}

struct StringQueryOperatorInput: InputValue {
	var eq: String?
	var `in`: [String]?
	var ne: String?
	var nin: [String]?
	var regex: String?
}

struct Subdivision: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func code() throws -> StringID {
		try source.scalar(access: .init(field: "code", args: []))
	}
	
	func emoji() throws -> String? {
		try source.scalar(access: .init(field: "emoji", args: []))
	}
	
	func name() throws -> String {
		try source.scalar(access: .init(field: "name", args: []))
	}
}
