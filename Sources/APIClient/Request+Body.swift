import Foundation

// Entirely inspired by https://davedelong.com/blog/2020/06/30/http-in-swift-part-3-request-bodies/ - thanks Dave!
public protocol RequestBody: CustomStringConvertible {
	func encode() throws -> Data
	var headers: HTTPFields { get }
	var isEmpty: Bool { get }
}

extension RequestBody {
	public var headers: HTTPFields { return [:] }
	public var isEmpty: Bool { false }
}

public struct EmptyBody: RequestBody {
		public let isEmpty = true
		public init() { }
		public func encode() throws -> Data { Data() }
		public var description: String { "EmptyBody()" }
}

public struct DataBody: RequestBody {
	private let data: Data

	public let headers: HTTPFields

	public init(_ data: Data, headers: HTTPFields = [:]) {
		self.data = data
		self.headers = headers
	}

	public func encode() throws -> Data {
		data
	}

	public var description: String { "DataBody(\(String(bytes: data, encoding: .utf8) ?? "undecodable"))" }
}

public struct JSONBody<Value: Encodable>: RequestBody {
	private let value: Value
	private let encoder: JSONEncoder

	public let headers: HTTPFields

	public init(
		_ value: Value,
		headers: HTTPFields = ["Content-Type": "application/json; charset=utf-8"],
		encoder: JSONEncoder = JSONEncoder()
	) {
		self.value = value
		self.headers = headers
		self.encoder = encoder
	}

	public func encode() throws -> Data {
		try encoder.encode(value)
	}

	public var description: String { "JSONBody(\(String(describing: value)))" }
}

public struct FormBody: RequestBody {
	public let headers = [
		"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"
	]

	private let values: [URLQueryItem]

	public init(_ values: [URLQueryItem]) {
		self.values = values
	}

	public init(_ values: [String: String]) {
		let queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
		self.init(queryItems)
	}

	public func encode() throws -> Data {
		let pieces = values.map(urlEncode)
		let bodyString = pieces.joined(separator: "&")
		return Data(bodyString.utf8)
	}

	private func urlEncode(_ queryItem: URLQueryItem) -> String {
		let name = urlEncode(queryItem.name)
		let value = urlEncode(queryItem.value ?? "")
		return "\(name)=\(value)"
	}

	private func urlEncode(_ string: String) -> String {
		let allowedCharacters = CharacterSet.alphanumerics
		return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
	}

	public var description: String { "FormBody(\(values.map(urlEncode).joined(separator: "&")))" }
}

// Inspired by https://theswiftdev.com/easy-multipart-file-upload-for-swift/ - thanks Tibor!
public struct MultipartFormBody: RequestBody {
	public enum FormValue: Sendable {
		case name(key: String, value: String)
		case filename(key: String, filename: String, value: Data, contentType: String)
	}

	private let separator = "\r\n"
	private let boundary: String
	private let values: [FormValue]

	public var headers: HTTPFields

	public init(_ values: [FormValue], boundary: String = UUID().uuidString) {
		self.values = values
		self.boundary = boundary
		self.headers = ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
	}

	private func encodeValues() throws -> Data {
		var data = try values
			.map { value in
				switch value {
				case let .name(key, value):
					return Data("\(boundarySeparator)\(disposition(for: key))\(separator)\(separator)\(value)\(separator)".utf8)
				case let .filename(key, filename, value, contentType):
					var result = "\(boundarySeparator)\(disposition(for: key)); filename=\"\(filename)\"\(separator)Content-Type: \(contentType)\(separator)\(separator)"

					guard var data = result.data(using: .utf8) else {
						throw EncodingError.invalidValue(result, .init(codingPath: [], debugDescription: "Invalid UTF8 encoding in: \(result)"))
					}

					data.append(value)
					data.append(Data(separator.utf8))

					return data
				}
			}
			.reduce(into: Data(), { $0.append($1)})

			data.append(Data("--\(boundary)--".utf8))

			return data
	}

	public func encode() throws -> Data {
		try encodeValues()
	}

	private func disposition(for key: String) -> String {
		"Content-Disposition: form-data; name=\"\(key)\""
	}

	private var boundarySeparator: String {
		"--\(boundary)\(separator)"
	}

	public var description: String {
		guard let data = try? encodeValues() else {
			return "MultipartFormBody(undecodable)"
		}

		return "MultipartFormBody(\(String(data: data, encoding: .utf8) ?? "undecodable"))"
	}
}
