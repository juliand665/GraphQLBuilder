import Foundation

struct Schema: Codable {
	var description: String?
	var types: [TypeInfo]
	var queryType: TypeName
	var mutationType: TypeName?
	var subscriptionType: TypeName?
	var directives: [Directive]
}

struct TypeName: Codable {
	var name: String
}

final class TypeReference: Codable {
	var name: String?
	var kind: TypeKind
	var ofType: TypeReference?
}

struct TypeInfo: Codable {
	var kind: TypeKind
	var name: String
	var description: String?
	var fields: [Field]? // for object & interface
	var interfaces: [TypeReference]? // for object & interface
	var possibleTypes: [TypeReference]? // for interface & union
	var enumValues: [EnumValue]? // for enum
	var inputFields: [InputValue]? // for inputObject
	var specifiedByURL: URL? // for custom scalar
}

enum TypeKind: String, Codable {
	case scalar = "SCALAR"
	case object = "OBJECT"
	case interface = "INTERFACE"
	case union = "UNION"
	case `enum` = "ENUM"
	case inputObject = "INPUT_OBJECT"
	case list = "LIST"
	case nonNull = "NON_NULL"
}

struct Field: Codable {
	var name: String
	var description: String?
	var args: [InputValue]
	var type: TypeReference
}

struct InputValue: Codable {
	var name: String
	var description: String?
	var type: TypeReference
	var defaultValue: String?
}

struct EnumValue: Codable {
	var name: String
	var description: String?
}

struct Directive: Codable {
	var name: String
	var description: String?
	var locations: [Location]
	var args: [InputValue]
	var isRepeatable: Bool
	
	enum Location: String, Codable {
		case query = "QUERY"
		case mutation = "MUTATION"
		case subscription = "SUBSCRIPTION"
		case field = "FIELD"
		case fragmentDefinition = "FRAGMENT_DEFINITION"
		case fragmentSpread = "FRAGMENT_SPREAD"
		case inlineFragment = "INLINE_FRAGMENT"
		case variableDefinition = "VARIABLE_DEFINITION"
		case schema = "SCHEMA"
		case scalar = "SCALAR"
		case object = "OBJECT"
		case fieldDefinition = "FIELD_DEFINITION"
		case argumentDefinition = "ARGUMENT_DEFINITION"
		case interface = "INTERFACE"
		case union = "UNION"
		case `enum` = "ENUM"
		case enumValue = "ENUM_VALUE"
		case inputObject = "INPUT_OBJECT"
		case inputFieldDefinition = "INPUT_FIELD_DEFINITION"
	}
}
