import Foundation

struct AISummaryResponse: Decodable { let summary: String }

final class AIService {
    static let shared = AIService()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.API.timeout
        config.timeoutIntervalForResource = AppConfig.API.timeout
        return URLSession(configuration: config)
    }()

    func summarize(text: String, language: String = "en") async throws -> String {
        let base = AppConfig.API.cloudRunBaseURL
        guard let url = URL(string: base + "/ai/summarize") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["text": text, "lang": language]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(AISummaryResponse.self, from: data)
        return decoded.summary
    }
}


