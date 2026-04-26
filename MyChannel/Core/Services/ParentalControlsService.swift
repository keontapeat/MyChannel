//
//  ParentalControlsService.swift
//  MyChannel
//
//  Phase 184: Parental Controls & Family Mode.
//  Age-gated content, screen time, supervised profiles.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct FamilyProfile: Codable, Identifiable {
    let id: String
    let parentUid: String
    let childName: String
    let ageGroup: AgeGroup
    let screenTimeLimitMin: Int
    let allowedCategories: [String]
    let blockedChannels: [String]
    let searchEnabled: Bool
}

enum AgeGroup: String, Codable { case under5, age5to8, age9to12, teen }

struct ScreenTimeRecord: Codable, Identifiable {
    let id: String
    let profileId: String
    let date: Date
    let minutesWatched: Int
    let videosWatched: Int
}

// MARK: - Service

@MainActor
final class ParentalControlsService: ObservableObject {
    static let shared = ParentalControlsService()
    private init() {}

    @Published private(set) var profiles: [FamilyProfile] = []
    @Published var activeChildProfile: FamilyProfile?
    @Published var isFamilyMode: Bool = false
    @Published var remainingMinutes: Int = 0

    func loadProfiles(parentUid: String) async throws {
        guard AppConfig.Features.enableParentalControls else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("family_profiles").whereField("parentUid", isEqualTo: parentUid).getDocuments()
        profiles = snap.documents.compactMap { doc in
            let d = doc.data()
            return FamilyProfile(
                id: doc.documentID, parentUid: d["parentUid"] as? String ?? "",
                childName: d["childName"] as? String ?? "",
                ageGroup: AgeGroup(rawValue: d["ageGroup"] as? String ?? "") ?? .age5to8,
                screenTimeLimitMin: d["screenTimeLimitMin"] as? Int ?? 60,
                allowedCategories: d["allowedCategories"] as? [String] ?? [],
                blockedChannels: d["blockedChannels"] as? [String] ?? [],
                searchEnabled: d["searchEnabled"] as? Bool ?? false
            )
        }
        #endif
    }

    func activateChildProfile(_ profile: FamilyProfile) {
        guard AppConfig.Features.enableParentalControls else { return }
        activeChildProfile = profile
        isFamilyMode = true
        remainingMinutes = profile.screenTimeLimitMin
    }

    func deactivate(pin: String) -> Bool {
        guard pin == "1234" else { return false } // Real impl uses secure PIN
        activeChildProfile = nil
        isFamilyMode = false
        return true
    }

    func isContentAllowed(category: String, channelId: String) -> Bool {
        guard let profile = activeChildProfile else { return true }
        if profile.blockedChannels.contains(channelId) { return false }
        if !profile.allowedCategories.isEmpty && !profile.allowedCategories.contains(category) { return false }
        return true
    }

    func tickMinute() {
        guard isFamilyMode else { return }
        remainingMinutes = max(0, remainingMinutes - 1)
    }
}
