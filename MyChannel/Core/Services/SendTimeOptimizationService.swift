//
//  SendTimeOptimizationService.swift
//  MyChannel
//
//  Phase 53: Per-user ML push-notification send time.
//  Wraps `notification-timing` + `feed-personalization` Cloud Run services.
//  Stores quiet hours + category opt-in in Firestore at `users/{uid}/pushPrefs/default`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum PushCategory: String, Codable, CaseIterable {
    case newVideosFromSubscriptions
    case liveNow
    case comments
    case mentions
    case recommendations
    case creatorMilestones
    case productAnnouncements
}

struct PushPrefs: Codable, Equatable {
    var quietHoursStart: Int?          // 0..23 local
    var quietHoursEnd: Int?            // 0..23 local
    var enabledCategories: Set<PushCategory>

    static let `default` = PushPrefs(
        quietHoursStart: 22,
        quietHoursEnd: 7,
        enabledCategories: Set(PushCategory.allCases)
    )
}

struct SendTimeDecision {
    let shouldSend: Bool
    let scheduledAt: Date
    let reason: String
}

@MainActor
final class SendTimeOptimizationService: ObservableObject {
    static let shared = SendTimeOptimizationService()
    private init() {}

    @Published private(set) var prefs: PushPrefs = .default

    // MARK: - Prefs persistence

    func loadPrefs(uid: String) async {
        #if canImport(FirebaseFirestore)
        let doc = try? await Firestore.firestore()
            .collection("users").document(uid)
            .collection("pushPrefs").document("default").getDocument()
        guard let data = doc?.data() else { return }
        prefs = PushPrefs(
            quietHoursStart: data["quietHoursStart"] as? Int,
            quietHoursEnd: data["quietHoursEnd"] as? Int,
            enabledCategories: Set((data["enabledCategories"] as? [String] ?? [])
                .compactMap(PushCategory.init(rawValue:)))
        )
        #endif
    }

    func savePrefs(uid: String, prefs: PushPrefs) async throws {
        self.prefs = prefs
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("pushPrefs").document("default")
            .setData([
                "quietHoursStart": prefs.quietHoursStart as Any,
                "quietHoursEnd": prefs.quietHoursEnd as Any,
                "enabledCategories": prefs.enabledCategories.map { $0.rawValue }
            ], merge: true)
        #endif
    }

    // MARK: - Decision

    /// Ask the ML service for the best moment to deliver a notification of `category` to `uid`.
    /// Falls back to "now if outside quiet hours" if the model is unavailable.
    func decide(
        uid: String,
        category: PushCategory,
        earliest: Date = Date(),
        latest: Date = Date().addingTimeInterval(24*3600)
    ) async -> SendTimeDecision {
        guard AppConfig.Features.enableSmartPushTiming else {
            return localDecision(category: category, at: earliest)
        }
        guard prefs.enabledCategories.contains(category) else {
            return .init(shouldSend: false, scheduledAt: earliest, reason: "category_off")
        }

        struct Request: Encodable {
            let task: String
            let uid: String
            let category: String
            let earliest: Double
            let latest: Double
        }
        struct Raw: Decodable {
            let scheduled_at: Double?
            let reason: String?
        }

        do {
            let r: Raw = try await CloudRunAgentRouter.post(
                .notificationTiming,
                path: "/predict",
                body: Request(
                    task: "best_send_time",
                    uid: uid,
                    category: category.rawValue,
                    earliest: earliest.timeIntervalSince1970,
                    latest: latest.timeIntervalSince1970
                )
            )
            let date = Date(timeIntervalSince1970: r.scheduled_at ?? earliest.timeIntervalSince1970)
            return applyQuietHours(scheduled: date, reason: r.reason ?? "ml_ok")
        } catch {
            return localDecision(category: category, at: earliest)
        }
    }

    // MARK: - Helpers

    private func localDecision(category: PushCategory, at date: Date) -> SendTimeDecision {
        guard prefs.enabledCategories.contains(category) else {
            return .init(shouldSend: false, scheduledAt: date, reason: "category_off")
        }
        return applyQuietHours(scheduled: date, reason: "local_fallback")
    }

    private func applyQuietHours(scheduled: Date, reason: String) -> SendTimeDecision {
        guard let qs = prefs.quietHoursStart, let qe = prefs.quietHoursEnd else {
            return .init(shouldSend: true, scheduledAt: scheduled, reason: reason)
        }
        let hour = Calendar.current.component(.hour, from: scheduled)
        let inQuiet: Bool = qs < qe ? (hour >= qs && hour < qe) : (hour >= qs || hour < qe)
        guard inQuiet else { return .init(shouldSend: true, scheduledAt: scheduled, reason: reason) }
        // Defer until qe on the next applicable day.
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: scheduled)
        comps.hour = qe
        comps.minute = 0
        let bumped = Calendar.current.date(from: comps) ?? scheduled
        return .init(shouldSend: true, scheduledAt: bumped > scheduled ? bumped : bumped.addingTimeInterval(86400), reason: "\(reason)+quiet_hours")
    }
}
