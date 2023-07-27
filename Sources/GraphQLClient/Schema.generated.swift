import GraphQLBuilder

struct Continent: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func code() -> StringID {
		source.scalar(access: .init(key: "a", field: "code", args: []))
	}
	
	func countries() -> [Country] {
		source.object(access: .init(key: "b", field: "countries", args: []))
	}
	
	func name() -> String {
		source.scalar(access: .init(key: "c", field: "name", args: []))
	}
}

struct ContinentFilterInput: InputValue {
	var code: StringQueryOperatorInput?
}

struct Country: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func awsRegion() -> String {
		source.scalar(access: .init(key: "a", field: "awsRegion", args: []))
	}
	
	func capital() -> String? {
		source.scalar(access: .init(key: "b", field: "capital", args: []))
	}
	
	func code() -> StringID {
		source.scalar(access: .init(key: "c", field: "code", args: []))
	}
	
	func continent() -> Continent {
		source.object(access: .init(key: "d", field: "continent", args: []))
	}
	
	func currencies() -> [String] {
		source.scalar(access: .init(key: "e", field: "currencies", args: []))
	}
	
	func currency() -> String? {
		source.scalar(access: .init(key: "f", field: "currency", args: []))
	}
	
	func emoji() -> String {
		source.scalar(access: .init(key: "g", field: "emoji", args: []))
	}
	
	func emojiU() -> String {
		source.scalar(access: .init(key: "h", field: "emojiU", args: []))
	}
	
	func languages() -> [Language] {
		source.object(access: .init(key: "i", field: "languages", args: []))
	}
	
	func name(lang: String? = nil) -> String {
		source.scalar(access: .init(key: "j", field: "name", args: [
			.init(name: "lang", type: "String", value: lang),
		]))
	}
	
	func native() -> String {
		source.scalar(access: .init(key: "k", field: "native", args: []))
	}
	
	func phone() -> String {
		source.scalar(access: .init(key: "l", field: "phone", args: []))
	}
	
	func phones() -> [String] {
		source.scalar(access: .init(key: "m", field: "phones", args: []))
	}
	
	func states() -> [State] {
		source.object(access: .init(key: "n", field: "states", args: []))
	}
	
	func subdivisions() -> [Subdivision] {
		source.object(access: .init(key: "o", field: "subdivisions", args: []))
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
	
	func code() -> StringID {
		source.scalar(access: .init(key: "a", field: "code", args: []))
	}
	
	func name() -> String {
		source.scalar(access: .init(key: "b", field: "name", args: []))
	}
	
	func native() -> String {
		source.scalar(access: .init(key: "c", field: "native", args: []))
	}
	
	func rtl() -> Bool {
		source.scalar(access: .init(key: "d", field: "rtl", args: []))
	}
}

struct LanguageFilterInput: InputValue {
	var code: StringQueryOperatorInput?
}

struct Query: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func continent(code: StringID) -> Continent? {
		source.object(access: .init(key: "a", field: "continent", args: [
			.init(name: "code", type: "ID!", value: code),
		]))
	}
	
	func continents(filter: ContinentFilterInput? = nil) -> [Continent] {
		source.object(access: .init(key: "b", field: "continents", args: [
			.init(name: "filter", type: "ContinentFilterInput", value: filter),
		]))
	}
	
	func countries(filter: CountryFilterInput? = nil) -> [Country] {
		source.object(access: .init(key: "c", field: "countries", args: [
			.init(name: "filter", type: "CountryFilterInput", value: filter),
		]))
	}
	
	func country(code: StringID) -> Country? {
		source.object(access: .init(key: "d", field: "country", args: [
			.init(name: "code", type: "ID!", value: code),
		]))
	}
	
	func language(code: StringID) -> Language? {
		source.object(access: .init(key: "e", field: "language", args: [
			.init(name: "code", type: "ID!", value: code),
		]))
	}
	
	func languages(filter: LanguageFilterInput? = nil) -> [Language] {
		source.object(access: .init(key: "f", field: "languages", args: [
			.init(name: "filter", type: "LanguageFilterInput", value: filter),
		]))
	}
}

struct State: GraphQLObject {
	private var source: any DataSource
	
	init(source: any DataSource) { self.source = source }
	
	func code() -> String? {
		source.scalar(access: .init(key: "a", field: "code", args: []))
	}
	
	func country() -> Country {
		source.object(access: .init(key: "b", field: "country", args: []))
	}
	
	func name() -> String {
		source.scalar(access: .init(key: "c", field: "name", args: []))
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
	
	func code() -> StringID {
		source.scalar(access: .init(key: "a", field: "code", args: []))
	}
	
	func emoji() -> String? {
		source.scalar(access: .init(key: "b", field: "emoji", args: []))
	}
	
	func name() -> String {
		source.scalar(access: .init(key: "c", field: "name", args: []))
	}
}
