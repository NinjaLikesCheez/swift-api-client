import Foundation

public typealias HTTPFields = [String: String]

public final class Client {
	private lazy var session = URLSession.shared

	public let baseURL: URL

	public var defaultHeaders: HTTPFields?
	public let decoder: JSONDecoder

	public init(
		baseURL: URL,
		defaultHeaders: HTTPFields? = nil,
		decoder: JSONDecoder = JSONDecoder()
	) {
		self.baseURL = baseURL
		self.defaultHeaders = defaultHeaders
		self.decoder = decoder
	}

	public func request<Value>(_ request: Request<Value>) async throws(Error) -> Value {
		return try await send(request: request)
	}
}

extension Client {
	private func urlRequest<Value>(from request: Request<Value>) throws(Error) -> URLRequest {
		var url = baseURL
		if let path = request.path {
			url = url.appending(path: path)
		}

		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = request.method.rawValue
		urlRequest.allHTTPHeaderFields = (defaultHeaders ?? [:]).merging(request.headers, uniquingKeysWith: { _, new in new })

		do {
			urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request.body as Any, options: [])
		} catch {
			throw .encoding(error)
		}

		return urlRequest
	}

	private func send<Value>(request: Request<Value>) async throws(Error) -> Value {
		do {
			let (data, response) =  try await session.data(for: urlRequest(from: request))

			guard let httpResponse = response as? HTTPURLResponse else {
				throw Error.invalidResponse(response)
			}

			guard httpResponse.statusCode == 200 else {
				// TODO: add validate to Request to allow custom validation of a response
				throw Error.invalidResponse(httpResponse)
			}

			return try decode(data: data, from: request)
		} catch let error as Error {
			throw error
		} catch let error as URLError {
			throw .request(error)
		} catch {
			throw .unknownRequestError(error)
		}
	}

	private func decode<Value>(data: Data, from request: Request<Value>) throws(Error) -> Value {
		do {
			return try JSONDecoder().decode(Value.self, from: data)
		} catch {
			throw .decoding(error)
		}
	}
}

public extension Client {
	enum Error: Swift.Error {
		case invalidResponse(URLResponse)
		case request(URLError)
		case unknownRequestError(Swift.Error)
		case encoding(Swift.Error)
		case decoding(Swift.Error)
	}
}
