import Foundation

// Apple only added `decode(_:from:configuration:)` in 2023 (iOS 17, macOS 14), so we'd rather not require it. instead we'll use the ugly classic userInfo hack as a shim on older platforms
extension JSONDecoder {
	private static let key = CodingUserInfoKey(rawValue: UUID().uuidString)!
	
	func backportedDecode<T: DecodableWithConfiguration>(
		_: T.Type = T.self, from data: Data, configuration: T.DecodingConfiguration
	) throws -> T {
		if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, macCatalyst 17, *) {
			return try decode(T.self, from: data, configuration: configuration)
		} else {
			userInfo[Self.key] = configuration
			defer { userInfo[Self.key] = nil }
			return try decode(ConfigurationExtractor<T>.self, from: data).value
		}
	}
	
	private struct ConfigurationExtractor<Value: DecodableWithConfiguration>: Decodable {
		var value: Value
		
		init(from decoder: Decoder) throws {
			let configuration = decoder.userInfo[key]! as! Value.DecodingConfiguration
			self.value = try .init(from: decoder, configuration: configuration)
		}
	}
}
