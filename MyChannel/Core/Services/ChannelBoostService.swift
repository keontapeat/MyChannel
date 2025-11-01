import Foundation
import StoreKit

struct ChannelBoostConfig {
    let apiBase: URL
    let token: String

    init(apiBase: URL? = nil, token: String? = nil) {
        if let apiBase = apiBase, let token = token {
            self.apiBase = apiBase
            self.token = token
            return
        }
        let info = Bundle.main.infoDictionary ?? [:]
        let baseString = (info["CHANNELBOOST_BASE_URL"] as? String) ?? "https://api.mychannel.live"
        let tokenString = (info["CHANNELBOOST_TOKEN"] as? String) ?? ""
        self.apiBase = URL(string: baseString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) ?? URL(string: "http://localhost:8877")!
        self.token = tokenString
    }
}

enum ChannelBoostError: Error {
    case invalidURL
    case http(Int)
    case decoding
}

struct ChannelBoostService {
    static var shared = ChannelBoostService()

    private let config: ChannelBoostConfig
    private let session: URLSession

    init(config: ChannelBoostConfig = ChannelBoostConfig(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Models
    struct ReferralResponse: Codable { let code: String; let url: String }
    struct ReviewEligibility: Codable { let eligible: Bool; let reason: String? }

    // MARK: - Helpers
    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: config.apiBase) else { throw ChannelBoostError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            let data = try JSONEncoder().encode(AnyEncodable(body))
            req.httpBody = data
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
            throw ChannelBoostError.http(http.statusCode)
        }
        if T.self == Empty.self { return Empty() as! T }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw ChannelBoostError.decoding }
    }

    // MARK: - API
    @discardableResult
    func createReferral(userId: String, source: String = "app", campaign: String? = nil) async throws -> ReferralResponse {
        var comps = URLComponents(url: config.apiBase.appendingPathComponent("/referral/create"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "user_id", value: userId), URLQueryItem(name: "source", value: source)]
        if let c = campaign { items.append(URLQueryItem(name: "campaign", value: c)) }
        comps.queryItems = items
        let path = comps.url!.absoluteString.replacingOccurrences(of: config.apiBase.absoluteString, with: "")
        return try await request(path, method: "GET")
    }

    struct InstallEvent: Encodable { let platform: String; let locale: String; let source: String?; let campaign: String?; let referral: String? }
    func logInstall(platform: String = "ios", locale: String, source: String? = nil, campaign: String? = nil, referral: String? = nil) async {
        let payload = InstallEvent(platform: platform, locale: locale, source: source, campaign: campaign, referral: referral)
        _ = try? await request("/events/install", method: "POST", body: payload) as Empty
    }

    struct FunnelEvent: Encodable { let user_id: String; let step: String }
    func funnelStep(userId: String, step: String) async {
        _ = try? await request("/events/funnel", method: "POST", body: FunnelEvent(user_id: userId, step: step)) as Empty
    }

    func isReviewEligible(userId: String) async -> ReviewEligibility? {
        struct Req: Encodable { let user_id: String }
        return try? await request("/reviews/eligible", method: "POST", body: Req(user_id: userId))
    }

    func logReview(userId: String, deviceHash: String, outcome: String) async {
        struct Req: Encodable { let user_id: String; let device_hash: String; let outcome: String }
        _ = try? await request("/reviews/log", method: "POST", body: Req(user_id: userId, device_hash: deviceHash, outcome: outcome)) as Empty
    }

    // MARK: - UX Helpers
    @MainActor
    func presentReviewIfEligible(userId: String) async {
        guard let elig = await isReviewEligible(userId: userId), elig.eligible else { return }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            await logReview(userId: userId, deviceHash: deviceIdentifierHash(), outcome: "shown")
        }
    }

    private func deviceIdentifierHash() -> String {
        let id = UIDevice.current.identifierForVendor?.uuidString ?? ""
        return String(id.hashValue)
    }
}

// Wrapper to encode unknown Encodable at runtime
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

private struct Empty: Decodable {}



