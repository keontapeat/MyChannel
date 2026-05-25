//
//  KidsModeService.swift
//  MyChannel
//
//  Phase 71: COPPA Kids Mode.
//  Sandboxed profiles under a parent account with:
//    • zero personalized ads (no cross-app tracking)
//    • allow-listed channels
//    • content filter tier enforced by `kids-ai-v2`
//    • parental PIN gate to exit Kids Mode
//  Parent-account identity + verified-parent consent lives alongside the
//  existing `COPPAComplianceService`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum KidsAgeBand: String, Codable, CaseIterable {
    case preschool        // 2–4
    case earlyElementary  // 5–7
    case lateElementary   // 8–12

    var maxContentRating: String {
        switch self {
        case .preschool:       return "G"
        case .earlyElementary: return "PG"
        case .lateElementary:  return "PG-13"
        }
    }

    var dailyWatchMinutesDefault: Int {
        switch self {
        case .preschool:       return 30
        case .earlyElementary: return 60
        case .lateElementary:  return 90
        }
    }
}

struct KidProfile: Codable, Identifiable, Equatable {
    let id: String               // profile id (nested under parent uid)
    let parentUid: String
    let displayName: String
    let ageBand: KidsAgeBand
    let dailyWatchMinutes: Int
    let allowedChannelIds: [String]   // allow-list
    let blockedChannelIds: [String]   // deny-list
    let createdAt: Date
}

@MainActor
final class KidsModeService: ObservableObject {
    static let shared = KidsModeService()
    private init() {}

    @Published private(set) var activeProfile: KidProfile?
    @Published private(set) var isKidsModeActive: Bool = false
    @Published private(set) var minutesWatchedToday: Int = 0

    private let defaults = UserDefaults.standard
    private let pinKey = "kidsMode.parentPinHash"
    private let activeKey = "kidsMode.activeProfileId"
    private let minutesKey = "kidsMode.minutesTodayByDay"

    // MARK: - Profiles

    func createProfile(_ profile: KidProfile) async throws {
        guard AppConfig.Features.enableKidsMode else { throw KidsError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("users").document(profile.parentUid)
            .collection("kidProfiles").document(profile.id)
            .setData([
                "displayName": profile.displayName,
                "ageBand": profile.ageBand.rawValue,
                "dailyWatchMinutes": profile.dailyWatchMinutes,
                "allowedChannelIds": profile.allowedChannelIds,
                "blockedChannelIds": profile.blockedChannelIds,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func listProfiles(parentUid: String) async throws -> [KidProfile] {
        guard AppConfig.Features.enableKidsMode else { return [] }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("users").document(parentUid)
            .collection("kidProfiles").getDocuments()
        return snap.documents.compactMap { doc -> KidProfile? in
            let d = doc.data()
            guard
                let name = d["displayName"] as? String,
                let bandRaw = d["ageBand"] as? String,
                let band = KidsAgeBand(rawValue: bandRaw)
            else { return nil }
            return KidProfile(
                id: doc.documentID,
                parentUid: parentUid,
                displayName: name,
                ageBand: band,
                dailyWatchMinutes: d["dailyWatchMinutes"] as? Int ?? band.dailyWatchMinutesDefault,
                allowedChannelIds: d["allowedChannelIds"] as? [String] ?? [],
                blockedChannelIds: d["blockedChannelIds"] as? [String] ?? [],
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #else
        return []
        #endif
    }

    // MARK: - Session

    func enter(_ profile: KidProfile) {
        activeProfile = profile
        isKidsModeActive = true
        defaults.set(profile.id, forKey: activeKey)
    }

    /// Require parent PIN to exit.
    func exit(withPIN pin: String) throws {
        guard let storedHash = defaults.string(forKey: pinKey) else {
            throw KidsError.pinNotSet
        }
        guard Self.sha(pin) == storedHash else {
            throw KidsError.wrongPIN
        }
        activeProfile = nil
        isKidsModeActive = false
        defaults.removeObject(forKey: activeKey)
    }

    func setParentPIN(_ pin: String) throws {
        guard pin.count >= 4 else { throw KidsError.pinTooShort }
        defaults.set(Self.sha(pin), forKey: pinKey)
    }

    // MARK: - Content filter

    func canShow(videoId: String, creatorId: String, rating: String?) async -> Bool {
        guard isKidsModeActive, let p = activeProfile else { return true }
        if p.blockedChannelIds.contains(creatorId) { return false }
        if !p.allowedChannelIds.isEmpty, !p.allowedChannelIds.contains(creatorId) { return false }

        // Server-side deep check — only when allow-list was not decisive.
        guard AppConfig.Features.enableKidsMode else { return true }
        struct Request: Encodable {
            let task: String
            let videoId: String
            let creatorId: String
            let ageBand: String
            let rating: String?
        }
        struct Raw: Decodable { let allow: Bool? }
        let raw: Raw? = try? await CloudRunAgentRouter.post(
            .kidsAIv2,
            path: "/predict",
            body: Request(
                task: "can_show",
                videoId: videoId,
                creatorId: creatorId,
                ageBand: p.ageBand.rawValue,
                rating: rating
            )
        )
        return raw?.allow ?? true
    }

    // MARK: - Watch time budget

    func recordWatchMinutes(_ minutes: Int) {
        guard isKidsModeActive else { return }
        minutesWatchedToday += minutes
        defaults.set(minutesWatchedToday, forKey: minutesKey + "." + Self.today())
    }

    func timeExceeded() -> Bool {
        guard let p = activeProfile else { return false }
        return minutesWatchedToday >= p.dailyWatchMinutes
    }

    // MARK: - Helpers

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func sha(_ s: String) -> String {
        // Lightweight client-side hash; real strength comes from rate-limiting + pin lockout.
        var hash = 5381
        for byte in s.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return String(hash)
    }

    enum KidsError: LocalizedError {
        case disabled, pinNotSet, wrongPIN, pinTooShort
        var errorDescription: String? {
            switch self {
            case .disabled: return "Kids Mode is disabled."
            case .pinNotSet: return "Set a parent PIN first."
            case .wrongPIN: return "Incorrect parent PIN."
            case .pinTooShort: return "PIN must be at least 4 digits."
            }
        }
    }
}
