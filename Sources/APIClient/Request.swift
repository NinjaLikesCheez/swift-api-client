import Foundation

public struct VoidResponse: Decodable {}

public enum HTTPMethod: String {
	case get = "GET"
	case head = "HEAD"
	case options = "OPTIONS"
	case trace = "TRACE"
	case put = "PUT"
	case delete = "DELETE"
	case post = "POST"
	case patch = "PATCH"
	case connect = "CONNECT"
}

public struct Request<Value: Decodable> {
	public let method: HTTPMethod
	public let path: String?
	public let headers: HTTPFields
	public let body: [String: Any]?

	public init(
		method: HTTPMethod,
		path: String? = nil,
		headers: HTTPFields = [:],
		body: [String: Any]? = nil
	) {
		self.method = method
		self.path = path
		self.headers = headers
		self.body = body
	}
}

public extension Request where Value == VoidResponse {
	init(
		method: HTTPMethod,
		path: String,
		headers: HTTPFields = [:],
		body: [String: Any]? = nil
	) {
		self.init(
			method: method,
			path: path,
			headers: headers,
			body: body
		)
	}
}
