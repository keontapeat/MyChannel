import Foundation

struct LiveControlService {
    static let shared = LiveControlService()
    private init() {}

    struct StartRequest: Codable {
        let title: String
        let description: String?
        let category: String
        let isPublic: Bool
        let enableChat: Bool
        let saveReplay: Bool
        let userId: String
    }

    struct StartResponse: Codable { let id: String; let streamKey: String; let rtmpUrl: String; let hlsUrl: String }
    struct StatusResponse: Codable { let id: String; let status: String; let rtmpUrl: String?; let hlsUrl: String? }

    private func buildURL(_ path: String) -> URL? {
        // Use API Gateway if available; otherwise fall back to baseURL
        let base = AppConfig.API.gatewayBaseURL
        return URL(string: base + path)
    }

    func startLive(_ req: StartRequest) async throws -> StartResponse {
        guard let url = buildURL("/live/start") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(req)
        let (data, response) = try await URLSession.configured.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw NetworkError.invalidResponse }
        return try JSONDecoder().decode(StartResponse.self, from: data)
    }

    func endLive(id: String) async {
        guard let url = buildURL("/live/end") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["id": id])
        _ = try? await URLSession.configured.data(for: request)
    }

    func status(id: String) async throws -> StatusResponse {
        guard let url = buildURL("/live/status/\(id)") else { throw NetworkError.invalidURL }
        let (data, response) = try await URLSession.configured.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw NetworkError.invalidResponse }
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
}




