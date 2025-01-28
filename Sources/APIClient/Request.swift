import Foundation

public protocol Request {
    associatedtype Response: Decodable

    var method: HTTPMethod { get }
    var path: String? { get }
    var headers: HTTPFields { get }
    var body: RequestBody? { get }
    var prepare: ((URLRequest) -> URLRequest) { get }
    var transform: ((Data, HTTPURLResponse) throws -> Response)? { get }
}

public extension Request {
    var allHeaders: HTTPFields {
        headers.merging(body?.headers ?? [:], uniquingKeysWith: { _, new in new })
    }
}

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
