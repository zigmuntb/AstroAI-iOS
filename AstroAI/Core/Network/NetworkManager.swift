//
//  NetworkManager.swift
//  AstroAI
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct Endpoint {
    let path: String
    var method: HTTPMethod = .get
    var query: [String: String] = [:]
    var headers: [String: String] = [:]
    var body: Encodable? = nil
}

enum NetworkError: LocalizedError {
    case invalidURL
    case offline
    case server(statusCode: Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid request URL."
        case .offline: "No internet connection."
        case .server(let code): "Server responded with status \(code)."
        case .decoding: "Unable to read server response."
        case .transport(let error): error.localizedDescription
        }
    }
}

protocol NetworkManaging {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func send(_ endpoint: Endpoint) async throws
}

/// Thin URLSession wrapper. Every remote service (Supabase REST, edge functions, AI proxy)
/// talks to the backend through this manager.
final class NetworkManager: NetworkManaging {
    private let baseURL: URL
    private let session: URLSession
    private let defaultHeaders: [String: String]
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.session = session

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await perform(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    // MARK: - Private

    private func perform(_ endpoint: Endpoint) async throws -> Data {
        let request = try makeRequest(endpoint)
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NetworkError.offline
        } catch {
            throw NetworkError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NetworkError.server(statusCode: http.statusCode)
        }
        return data
    }

    private func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.query.isEmpty {
            components?.queryItems = endpoint.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        defaultHeaders.merging(endpoint.headers) { $1 }.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }
}
