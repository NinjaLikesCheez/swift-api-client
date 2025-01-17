import Foundation
import Logging

#if canImport(Combine)
		import Combine
#endif

// URLSession in exists in FoundationNetworking on Linux
#if canImport(FoundationNetworking)
		import FoundationNetworking
#endif

public typealias HTTPFields = [String: String]

public extension Client {
	enum RequestError: Swift.Error {
		case urlError(URLError)
		case invalidRequest(Swift.Error)
		case unknown(Swift.Error)
	}

	enum EncodingError: Swift.Error {
		case invalidUTF8
	}

	enum Error: Swift.Error {
		case encoding(Swift.Error)
		case decoding(Swift.Error)
		case request(RequestError)
		case response(ResponseError)
	}
}

public struct Client<ResponseError: Swift.Error>: Sendable {
	private let session = URLSession.shared
	public typealias ResponseError = ResponseError

	public let baseURL: URL
	public let defaultHeaders: HTTPFields?
	public let decoder: JSONDecoder

	public let validate: @Sendable (Data, HTTPURLResponse) throws(Error) -> Void
	public let prepare: @Sendable (URLRequest) -> URLRequest

	private let logger = Logger(label: "swift-api-client.Client")

	public init(
		baseURL: URL,
		defaultHeaders: HTTPFields? = nil,
		decoder: JSONDecoder = JSONDecoder(),
		validate: @Sendable @escaping (Data, HTTPURLResponse) throws(Error) -> Void,
		prepare: @Sendable @escaping (URLRequest) -> URLRequest = { $0 }
	) {
		self.baseURL = baseURL
		self.defaultHeaders = defaultHeaders
		self.decoder = decoder
		self.validate = validate
		self.prepare = prepare
	}

	@discardableResult
	public func request<Value>(_ request: Request<Value>) async throws(Error) -> Value {
		try await send(request: request)
	}
}

extension Client {
	private func urlRequest<Value>(from request: Request<Value>) throws(Error) -> URLRequest {
		var url = baseURL

		if let path = request.path, !path.isEmpty {
			url = url.appending(path: path)
		}

		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = request.method.rawValue
		urlRequest.allHTTPHeaderFields = (defaultHeaders ?? [:]).merging(request.allHeaders, uniquingKeysWith: { _, new in new })

		do {
			if let body = request.body {
				urlRequest.httpBody = try body.encode()
			}
		} catch {
			throw .encoding(error)
		}

		return request.prepare(prepare(urlRequest))
	}
}

// Swift Concurrency
extension Client {
	private func send<Value>(
		request: Request<Value>
	) async throws(Error) -> Value {
		do {
			let urlRequest = try urlRequest(from: request)
			logger.debug("request: \(String(describing: request.body))")
			let (data, response) =  try await session.data(for: urlRequest)
			let httpResponse = response as! HTTPURLResponse

			logger.debug("response: \(httpResponse), data: \(String(bytes: data, encoding: .utf8) ?? "nil")")

			try validate(data, httpResponse)

			let transform = request.transform ?? decode

			return try transform(data, httpResponse)
		} catch let error as Error {
			throw error
		} catch let error as URLError {
			throw .request(.urlError(error))
		} catch {
			throw .request(.unknown(error))
		}
	}

	private func decode<Value: Decodable>(data: Data, _: URLResponse) throws(Error) -> Value {
		do {
//			var debugText: String = ""

//			do {
//					return try decoder.decode(Value.self, from: data)
//			} catch DecodingError.dataCorrupted(let context) {
//					debugText = "\(context)"
//			} catch DecodingError.keyNotFound(let key, let context) {
//					debugText += "\nKey '\(key)' not found:\(context.debugDescription)."
//					debugText += "\ncodingPath: \(context.codingPath)."
//			} catch DecodingError.valueNotFound (let value, let context) {
//					debugText += "\nValue '\(value)' not found: \(context.debugDescription)."
//					debugText += "\ncodingPath: \(context.codingPath)."
//			} catch DecodingError.typeMismatch(let type, let context) {
//					debugText += "\nType '\(type)' mismatch: \(context.debugDescription)."
//					debugText += "\ncodingPath: \(context.codingPath)."
//			} catch {
//					debugText = error.localizedDescription
//			}
//			print("debugText: \(debugText)")
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
		func request<Value>(_ request: Request<Value>, retryOnAuthenticationFailure: Bool = true) -> AnyPublisher<Value, Error> {
			send(request: request)
				.eraseToAnyPublisher()
		}
	}

	extension Client {
		private func send<Value>(request: Request<Value>, retryOnAuthenticationFailure: Bool = true) -> AnyPublisher<Value, Error> {
			do {
				return session.dataTaskPublisher(for: try urlRequest(from: request))
					.mapError { Client.Error.request(.urlError($0)) }
					.flatMap { [self] data, response -> AnyPublisher<Value, Error> in
						let httpResponse = response as! HTTPURLResponse

						logger.debug("response: \(httpResponse), data: \(String(decoding: data, as: UTF8.self))")

						do {
							try validate(data, httpResponse)
						} catch {
							return Fail(error: error as! Client.Error)
								.eraseToAnyPublisher()
						}

						let transform = request.transform ?? decode

						do {
							let value = try transform(data, httpResponse)

							return Just(value)
								.setFailureType(to: Error.self)
								.eraseToAnyPublisher()
						} catch let error as Error {
							return Fail(error: error)
								.eraseToAnyPublisher()
						} catch {
							return Fail(error: .request(.unknown(error)))
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
