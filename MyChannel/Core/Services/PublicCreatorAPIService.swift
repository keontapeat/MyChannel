//
//  PublicCreatorAPIService.swift
//  MyChannel
//
//  Phase 70: Public Creator API & webhooks.
//  Mints OAuth2 client credentials, lists registered webhooks, and exposes
//  the public developer-portal endpoints. Backing routes are hosted by the
//  `api-shield` / `gateway` Cloud Run services under `developers.mychannel.live`.
//

import Foundation

struct APIClient: Codable, Identifiable, Equatable {
    let id: String               // client_id
    let name: String
    let ownerUid: String
    let scopes: [APIScope]
    let createdAt: Date
    let lastUsedAt: Date?
    /// The secret is shown exactly once at creation time, never again.
    let secretMasked: String     // e.g. "sk_live_****...abcd"
}

enum APIScope: String, Codable, CaseIterable {
    case readVideos          = "videos:read"
    case writeVideos         = "videos:write"
    case readAnalytics       = "analytics:read"
    case readComments        = "comments:read"
    case writeComments       = "comments:write"
    case readChannel         = "channel:read"
    case writeChannel        = "channel:write"
    case manageWebhooks      = "webhooks:manage"
    case liveStreamsControl  = "livestreams:control"
}

enum WebhookEvent: String, Codable, CaseIterable {
    case videoPublished       = "video.published"
    case videoDeleted         = "video.deleted"
    case commentCreated       = "comment.created"
    case commentDeleted       = "comment.deleted"
    case subscriberGained     = "subscriber.gained"
    case liveStreamStarted    = "livestream.started"
    case liveStreamEnded      = "livestream.ended"
    case uploadCompleted      = "upload.completed"
}

struct WebhookEndpoint: Codable, Identifiable, Equatable {
    let id: String
    let ownerUid: String
    let url: URL
    let events: [WebhookEvent]
    let signingSecretMasked: String
    let active: Bool
    let createdAt: Date
    let lastDeliveryAt: Date?
    let lastDeliveryStatus: Int?
}

@MainActor
final class PublicCreatorAPIService: ObservableObject {
    static let shared = PublicCreatorAPIService()
    private init() {}

    private let portalBase = "https://developers.mychannel.live/v1"

    // MARK: - Clients

    func createClient(name: String, scopes: [APIScope], ownerUid: String) async throws -> (APIClient, plaintextSecret: String) {
        guard AppConfig.Features.enablePublicCreatorAPI else { throw APIError.disabled }
        struct Request: Encodable {
            let name: String
            let scopes: [String]
            let ownerUid: String
        }
        struct Raw: Decodable {
            let client_id: String
            let client_secret: String
            let secret_masked: String
            let created_at: Double
        }
        let body = Request(name: name, scopes: scopes.map { $0.rawValue }, ownerUid: ownerUid)
        let raw: Raw = try await callPortal("/clients", method: "POST", body: body)
        let client = APIClient(
            id: raw.client_id,
            name: name,
            ownerUid: ownerUid,
            scopes: scopes,
            createdAt: Date(timeIntervalSince1970: raw.created_at),
            lastUsedAt: nil,
            secretMasked: raw.secret_masked
        )
        return (client, raw.client_secret)
    }

    func listClients(ownerUid: String) async throws -> [APIClient] {
        guard AppConfig.Features.enablePublicCreatorAPI else { return [] }
        struct Raw: Decodable { let clients: [ClientRaw] }
        struct ClientRaw: Decodable {
            let client_id: String
            let name: String
            let scopes: [String]
            let created_at: Double
            let last_used_at: Double?
            let secret_masked: String
        }
        let r: Raw = try await callPortal("/clients?ownerUid=\(ownerUid)", method: "GET", body: _EmptyBody())
        return r.clients.map {
            APIClient(
                id: $0.client_id,
                name: $0.name,
                ownerUid: ownerUid,
                scopes: $0.scopes.compactMap(APIScope.init(rawValue:)),
                createdAt: Date(timeIntervalSince1970: $0.created_at),
                lastUsedAt: $0.last_used_at.map { Date(timeIntervalSince1970: $0) },
                secretMasked: $0.secret_masked
            )
        }
    }

    // MARK: - Webhooks

    func registerWebhook(url: URL, events: [WebhookEvent], ownerUid: String) async throws -> WebhookEndpoint {
        guard AppConfig.Features.enablePublicCreatorAPI else { throw APIError.disabled }
        struct Request: Encodable {
            let url: String
            let events: [String]
            let ownerUid: String
        }
        struct Raw: Decodable {
            let id: String
            let signing_secret_masked: String
            let created_at: Double
        }
        let r: Raw = try await callPortal("/webhooks", method: "POST", body: Request(
            url: url.absoluteString,
            events: events.map { $0.rawValue },
            ownerUid: ownerUid
        ))
        return WebhookEndpoint(
            id: r.id,
            ownerUid: ownerUid,
            url: url,
            events: events,
            signingSecretMasked: r.signing_secret_masked,
            active: true,
            createdAt: Date(timeIntervalSince1970: r.created_at),
            lastDeliveryAt: nil,
            lastDeliveryStatus: nil
        )
    }

    // MARK: - Transport

    private func callPortal<B: Encodable, T: Decodable>(
        _ path: String,
        method: String,
        body: B
    ) async throws -> T {
        guard let url = URL(string: portalBase + path) else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method != "GET" {
            req.httpBody = try JSONEncoder().encode(body)
        }
        // Attach Firebase ID token so the gateway can authorize as the creator.
        #if canImport(FirebaseAuth)
        if let token = try? await FirebaseAuth.Auth.auth().currentUser?.getIDToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        #endif

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "portal_error"
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? 0, msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private struct _EmptyBody: Encodable {}

    enum APIError: LocalizedError {
        case disabled, badURL, http(Int, String)
        var errorDescription: String? {
            switch self {
            case .disabled: return "Public API is disabled."
            case .badURL: return "Invalid portal URL."
            case .http(let code, let msg): return "Portal HTTP \(code): \(msg)"
            }
        }
    }
}

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
