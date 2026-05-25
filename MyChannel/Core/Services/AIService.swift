import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

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

    private func buildAuthHeaders() async -> [String: String] {
        var headers: [String: String] = ["Content-Type": "application/json"]
        let apiKey = AppSecrets.aiAPIKey
        if !apiKey.isEmpty { headers["x-api-key"] = apiKey }
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            do {
                let token = try await user.getIDToken()
                headers["Authorization"] = "Bearer \(token)"
            } catch { }
        }
        #endif
        return headers
    }

    func summarize(text: String, language: String = "en") async throws -> String {
        let base = AppConfig.API.gatewayBaseURL.isEmpty ? AppConfig.API.cloudRunBaseURL : AppConfig.API.gatewayBaseURL
        guard let url = URL(string: base + "/ai/summarize") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = await buildAuthHeaders()
        for (k, v) in headers { request.addValue(v, forHTTPHeaderField: k) }
        let body: [String: Any] = ["text": text, "lang": language]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(AISummaryResponse.self, from: data)
        return decoded.summary
    }

    struct AnalyzeVideoRequest: Encodable {
        let gcs_uri: String
        let features: [String]
        let video_id: String?
        let duration_seconds: Double?
    }

    struct AnalyzeVideoResponse: Decodable {
        let labels: [String]
        let shots: Int
        let explicit_content: Bool?
        let text_annotations: [String]
        let object_annotations: [String]
        let uri: String
    }

    func analyzeVideo(gcsUri: String, videoId: String? = nil, durationSeconds: Double? = nil) async throws -> AnalyzeVideoResponse {
        let base = AppConfig.API.gatewayBaseURL.isEmpty ? AppConfig.API.cloudRunBaseURL : AppConfig.API.gatewayBaseURL
        guard let url = URL(string: base + "/ai/analyzeVideo") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = await buildAuthHeaders()
        for (k, v) in headers { request.addValue(v, forHTTPHeaderField: k) }
        let body = AnalyzeVideoRequest(
            gcs_uri: gcsUri,
            features: ["LABEL_DETECTION", "SHOT_CHANGE_DETECTION", "EXPLICIT_CONTENT_DETECTION", "TEXT_DETECTION", "OBJECT_TRACKING"],
            video_id: videoId,
            duration_seconds: durationSeconds
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AnalyzeVideoResponse.self, from: data)
    }

    struct ScoreViralityRequest: Encodable {
        let labels: [String]
        let shots: Int
        let explicit_content: Bool?
        let duration_seconds: Double?
        let text_annotations: [String]
        let object_annotations: [String]
    }

    struct ScoreViralityResponse: Decodable { let score: Double }

    func scoreVirality(labels: [String], shots: Int, explicit: Bool?, duration: Double?, text: [String], objects: [String]) async throws -> Double {
        let base = AppConfig.API.gatewayBaseURL.isEmpty ? AppConfig.API.cloudRunBaseURL : AppConfig.API.gatewayBaseURL
        guard let url = URL(string: base + "/ai/scoreVirality") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = await buildAuthHeaders()
        for (k, v) in headers { request.addValue(v, forHTTPHeaderField: k) }
        let body = ScoreViralityRequest(labels: labels, shots: shots, explicit_content: explicit, duration_seconds: duration, text_annotations: text, object_annotations: objects)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ScoreViralityResponse.self, from: data).score
    }

    // Helper to decode arbitrary JSON values
    // no-op
}


