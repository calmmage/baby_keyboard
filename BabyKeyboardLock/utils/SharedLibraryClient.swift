import Foundation

enum SharedLibraryMediaKind: String, Codable {
    case image
    case video
    case music
}

struct SharedLibraryAsset: Codable, Identifiable, Equatable {
    let id: String
    let kind: SharedLibraryMediaKind
    let url: URL
    let pathname: String
    let bytes: Int
    let createdAt: String
}

struct SharedLibraryItem: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let createdAt: String
    let image: SharedLibraryAsset?
    let videos: [SharedLibraryAsset]
    let music: SharedLibraryAsset?
}

struct SharedLibraryFeed: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: String
    let source: String
    let items: [SharedLibraryItem]
    let warning: String?
}

enum SharedLibraryClientError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case server(status: Int, message: String)
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid library URL, for example http://localhost:3848."
        case .invalidResponse:
            return "The shared library returned an invalid response."
        case let .server(status, message):
            return "Library error \(status): \(message)"
        case let .unsupportedSchema(version):
            return "This app does not understand shared-library contract v\(version)."
        }
    }
}

private struct SharedLibraryAPIError: Decodable {
    let error: String?
    let friendlyMessage: String?
}

struct SharedLibraryClient {
    static let supportedSchemaVersion = 1

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func endpointURL(baseURL: String, includeDemo: Bool) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              components.host != nil else {
            throw SharedLibraryClientError.invalidBaseURL
        }

        components.path = "/api/shared-library"
        components.query = nil
        components.queryItems = includeDemo ? [URLQueryItem(name: "demo", value: "1")] : nil
        guard let url = components.url else {
            throw SharedLibraryClientError.invalidBaseURL
        }
        return url
    }

    static func playerURL(baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              components.host != nil else {
            throw SharedLibraryClientError.invalidBaseURL
        }
        components.path = "/baby"
        components.query = nil
        components.queryItems = nil
        guard let url = components.url else {
            throw SharedLibraryClientError.invalidBaseURL
        }
        return url
    }

    func fetch(baseURL: String, pin: String?, includeDemo: Bool = true) async throws -> SharedLibraryFeed {
        let url = try Self.endpointURL(baseURL: baseURL, includeDemo: includeDemo)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let pin, !pin.isEmpty {
            request.setValue(pin, forHTTPHeaderField: "x-access-pin")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharedLibraryClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONDecoder().decode(SharedLibraryAPIError.self, from: data)
            let message = payload?.friendlyMessage ?? payload?.error ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SharedLibraryClientError.server(status: httpResponse.statusCode, message: message)
        }

        let feed = try JSONDecoder().decode(SharedLibraryFeed.self, from: data)
        guard feed.schemaVersion == Self.supportedSchemaVersion else {
            throw SharedLibraryClientError.unsupportedSchema(feed.schemaVersion)
        }
        return feed
    }
}
