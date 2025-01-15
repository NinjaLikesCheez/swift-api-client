import Foundation

public struct EmptyResponse: Decodable, Sendable {
	public init() {}
}

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
	public let body: RequestBody?
	public let prepare: ((URLRequest) -> URLRequest)
	public let transform: ((Data, HTTPURLResponse) throws -> Value)?

	public init(
		method: HTTPMethod,
		path: String? = nil,
		headers: HTTPFields = [:],
		body: RequestBody? = nil,
		prepare: ((URLRequest) -> URLRequest)? = nil,
		transform: ((Data, HTTPURLResponse) throws -> Value)? = nil
	) {
		self.method = method
		self.path = path
		self.headers = headers
		self.body = body
		self.prepare = prepare ?? { $0 }
		self.transform = transform
	}

	var allHeaders: HTTPFields {
		headers.merging(body?.headers ?? [:], uniquingKeysWith: { _, new in new })
	}
}

