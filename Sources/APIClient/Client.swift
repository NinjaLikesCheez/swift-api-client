import Foundation
import Logging

#if canImport(Combine)
import Combine
#endif

// URLSession in exists in FoundationNetworking on Linux
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let logger = Logger(label: "swift-api-client.Client")

public typealias HTTPFields = [String: String]

public enum RequestError: Error {
	case urlError(URLError)
	case invalidRequest(Error)
	case unknown(Error)
}

public enum ClientError<ResponseError: Error>: Error {
	case encoding(Error)
	case decoding(Error)
	case request(RequestError)
	case response(ResponseError)
}

public protocol Client: Sendable {
    // associatedtype RequestType: Request
    associatedtype ResponseError: Swift.Error

    var baseURL: URL { get }
    var defaultHeaders: HTTPFields? { get }
    var decoder: JSONDecoder { get }
		var basicAuthentication: BasicAuthentication? { get }

    var validate: @Sendable (Data, HTTPURLResponse) throws(ClientError<ResponseError>) -> Void { get }
    var prepare: @Sendable (URLRequest) -> URLRequest { get }

		var session: URLSession { get }
}

public struct BasicAuthentication: Codable, Sendable {
	public let username: String
	public let password: String

	public init(username: String, password: String) {
		self.username = username
		self.password = password
	}

	var encoded: String {
		Data("\(username):\(password)".utf8).base64EncodedString()
	}
}

extension Client {
	private func urlRequest(from request: some Request) throws(ClientError<ResponseError>) -> URLRequest {
		var url = baseURL

		if let path = request.path, !path.isEmpty {
			url = url.appending(path: path)
		}

		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = request.method.rawValue

		var headers = (defaultHeaders ?? [:]).merging(request.headers) { _, new in new }
		if let basicAuthentication = basicAuthentication {
			headers["Authorization"] = "Basic \(basicAuthentication.encoded)"
		}
		urlRequest.allHTTPHeaderFields = headers

		do {
			if let body = try request.body() {
				urlRequest.httpBody = try body.encode()
				urlRequest.allHTTPHeaderFields?.merge(body.headers) { _, new in new }
			}
		} catch {
			throw .encoding(error)
		}

		return request.prepare(prepare(urlRequest))
	}
}

// Swift Concurrency
extension Client {
	@discardableResult
	public func send<R: Request>(
		request: R
	) async throws(ClientError<ResponseError>) -> R.Response {
		do {
			let urlRequest = try urlRequest(from: request)
			logger.debug("request: \(String(describing: request.body))")
			let (data, response) =  try await session.data(for: urlRequest)
			// swiftlint:disable:next force_cast
			let httpResponse = response as! HTTPURLResponse

			logger.debug("response: \(httpResponse), data: \(String(bytes: data, encoding: .utf8) ?? "nil")")

			try validate(data, httpResponse)

			let transform = request.transform ?? decode

			return try transform(data, httpResponse)
		} catch let error as ClientError<ResponseError> {
			throw error
		} catch let error as URLError {
			throw .request(.urlError(error))
		} catch {
			throw .request(.unknown(error))
		}
	}

	private func decode<Value: Decodable>(data: Data, _: URLResponse) throws(ClientError<ResponseError>) -> Value {
		do {
			return try decoder.decode(Value.self, from: data)
		} catch {
			throw .decoding(error)
		}
	}
}

// Combine
#if canImport(Combine)
public extension Client {
	/// Sends a request to the server.
	/// - Parameter request: The request to be sent to the server.
	/// - Returns: A publisher that emits a value when the request completes.
	@discardableResult
	func send<R: Request>(request: R) -> AnyPublisher<R.Response, ClientError<ResponseError>> {
		do {
			return session.dataTaskPublisher(for: try urlRequest(from: request))
				.mapError { ClientError<ResponseError>.request(.urlError($0)) }
				.flatMap { [self] data, response -> AnyPublisher<R.Response, ClientError<ResponseError>> in
					// swiftlint:disable:next force_cast
					let httpResponse = response as! HTTPURLResponse

					logger.debug("response: \(httpResponse), data: \(String(data: data, encoding: .utf8) ?? "nil")")

					do throws(ClientError<ResponseError>) {
						try validate(data, httpResponse)
					} catch {
						return Fail(error: error)
							.eraseToAnyPublisher()
					}

					let transform = request.transform ?? decode

					do {
						let value = try transform(data, httpResponse)

						return Just(value)
							.setFailureType(to: ClientError<ResponseError>.self)
							.eraseToAnyPublisher()
					} catch {
						return Fail(error: ClientError<ResponseError>.request(.unknown(error)))
							.eraseToAnyPublisher()
					}
				}
				.eraseToAnyPublisher()
		} catch {
			return Fail(error: error).eraseToAnyPublisher()
		}
	}
}

#endif
