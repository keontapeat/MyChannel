import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct StorySignedUrlRequest: Codable {
    let filename: String
    let contentType: String
}

struct StorySignedUrlResponse: Codable {
    let url: String
    let method: String
    let bucket: String
    let object: String
    let getUrl: String
}

struct StoryFinalizeRequest: Codable {
    let object: String
    let bucket: String?
    let contentType: String?
}

struct StoryFinalizeResponse: Codable {
    let url: String
    let publicUrl: String
    let bucket: String
    let object: String
    let contentType: String?

    enum CodingKeys: String, CodingKey {
        case url
        case publicUrl = "publicUrl"
        case bucket
        case object
        case contentType
    }
}

struct CreateStoryRequest: Codable {
    let mediaUrl: String
    let mediaType: String
    let duration: Double
    let caption: String?
    let text: String?
    let backgroundColor: String?
    let textColor: String?
    let music: StoryMusic?
    let stickers: [StorySticker]
    let audience: String
}

struct CreateStoryResponse: Codable {
    let story: Story
}

struct StoriesResponse: Codable {
    let stories: [Story]
}

@MainActor
class StoryAPIService: ObservableObject {
    static let shared = StoryAPIService()
    private let apiClient = APIClient.shared

    private init() {}

    // Returns Firebase ID token for authenticated requests
    private func authHeaders() async -> [String: String]? {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return nil }
        guard let token = try? await user.getIDToken() else { return nil }
        return ["Authorization": "Bearer \(token)"]
        #else
        return nil
        #endif
    }

    func getSignedUploadUrl(filename: String, contentType: String) async throws -> StorySignedUrlResponse {
        let req = StorySignedUrlRequest(filename: filename, contentType: contentType)
        let headers = await authHeaders()
        return try await apiClient.post(endpoint: "/v1/stories/signed-url", body: req, headers: headers, responseType: StorySignedUrlResponse.self)
    }

    func uploadMedia(data: Data, to signedUrl: String, contentType: String) async throws {
        guard let url = URL(string: signedUrl) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (body, response) = try await URLSession.shared.data(for: request)
        _ = body
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, "Upload failed")
        }
    }

    func finalize(object: String, bucket: String?, contentType: String?) async throws -> StoryFinalizeResponse {
        let req = StoryFinalizeRequest(object: object, bucket: bucket, contentType: contentType)
        let headers = await authHeaders()
        return try await apiClient.post(endpoint: "/v1/stories/finalize", body: req, headers: headers, responseType: StoryFinalizeResponse.self)
    }

    func createStory(
        mediaUrl: String,
        mediaType: Story.MediaType,
        duration: Double,
        caption: String?,
        text: String?,
        backgroundColor: String?,
        textColor: String?,
        music: StoryMusic?,
        stickers: [StorySticker],
        audience: String
    ) async throws -> Story {
        let req = CreateStoryRequest(
            mediaUrl: mediaUrl,
            mediaType: mediaType.rawValue,
            duration: duration,
            caption: caption,
            text: text,
            backgroundColor: backgroundColor,
            textColor: textColor,
            music: music,
            stickers: stickers,
            audience: audience
        )
        let headers = await authHeaders()
        let res: CreateStoryResponse = try await apiClient.post(endpoint: "/v1/stories", body: req, headers: headers, responseType: CreateStoryResponse.self)
        return res.story
    }

    func fetchFollowingStories(limit: Int = 24) async throws -> [Story] {
        let query = ["limit": String(limit)]
        let headers = await authHeaders()
        let res: StoriesResponse = try await apiClient.get(endpoint: "/v1/stories/following", queryParameters: query, headers: headers, responseType: StoriesResponse.self)
        return res.stories
    }
}
