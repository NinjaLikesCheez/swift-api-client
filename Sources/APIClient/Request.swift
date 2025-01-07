import Foundation

public struct EmptyResponse: Decodable, Sendable {}

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

	public let transform: ((Data) throws -> Value)?

	public init(
		method: HTTPMethod,
		path: String? = nil,
		headers: HTTPFields = [:],
		body: [String: Any]? = nil,
		transform: ((Data) throws -> Value)? = nil
	) {
		self.method = method
		self.path = path
		self.headers = headers
		self.body = body
		self.transform = transform
	}
}
