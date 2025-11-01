import Foundation

struct PayAPIService {
    static let shared = PayAPIService()
    private init() {}

    struct ConnectLink: Codable { let url: String }

    struct ConnectLinkRequest: Codable { let userId: String }

    func createConnectLink(userId: String) async throws -> URL {
        let body = ConnectLinkRequest(userId: userId)
        let res: ConnectLink = try await NetworkService.shared.post(
            endpoint: .custom("/pay/connect/link"),
            body: body,
            responseType: ConnectLink.self
        )
        guard let u = URL(string: res.url) else { throw URLError(.badURL) }
        return u
    }

    struct TipRequest: Codable { let toUserId: String; let amount: Int; let currency: String }

    func tip(to creatorId: String, amountCents: Int, currency: String = "usd") async {
        let body = TipRequest(toUserId: creatorId, amount: amountCents, currency: currency)
        _ = try? await NetworkService.shared.post(endpoint: .custom("/pay/tip"), body: body, responseType: MessageResponse.self)
    }

    struct ToggleRequest: Codable { let userId: String; let enabled: Bool }
    struct SettingsResponse: Codable { let tipsEnabled: Bool; let membershipsEnabled: Bool }

    func getMonetizationSettings(userId: String) async throws -> SettingsResponse {
        return try await NetworkService.shared.get(endpoint: .custom("/pay/settings/\(userId)"), responseType: SettingsResponse.self)
    }

    func setTipsEnabled(userId: String, enabled: Bool) async throws {
        let body = ToggleRequest(userId: userId, enabled: enabled)
        let _: MessageResponse = try await NetworkService.shared.post(endpoint: .custom("/pay/tips/enable"), body: body, responseType: MessageResponse.self)
    }

    func setMembershipsEnabled(userId: String, enabled: Bool) async throws {
        let body = ToggleRequest(userId: userId, enabled: enabled)
        let _: MessageResponse = try await NetworkService.shared.post(endpoint: .custom("/pay/memberships/enable"), body: body, responseType: MessageResponse.self)
    }
}


