//
//  ContentCalendarService.swift
//  MyChannel
//
//  Phase 167: Content Calendar & Scheduler.
//  Drag-drop scheduling, optimal time prediction, cross-platform sync.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct ScheduledPost: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let videoId: String?
    let title: String
    let scheduledAt: Date
    let platforms: [String]
    let status: ScheduleStatus
    let contentType: String
}

enum ScheduleStatus: String, Codable { case draft, scheduled, published, failed }

struct OptimalTimeSlot: Codable, Identifiable {
    let id: String
    let dayOfWeek: Int
    let hour: Int
    let predictedEngagement: Double
    let audienceOnlinePercent: Double
}

// MARK: - Service

@MainActor
final class ContentCalendarService: ObservableObject {
    static let shared = ContentCalendarService()
    private init() {}

    @Published private(set) var scheduled: [ScheduledPost] = []
    @Published private(set) var optimalSlots: [OptimalTimeSlot] = []

    func loadSchedule(creatorUid: String) async throws {
        guard AppConfig.Features.enableContentCalendar else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("content_calendar").whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "scheduledAt").getDocuments()
        scheduled = snap.documents.compactMap { doc in
            let d = doc.data()
            return ScheduledPost(
                id: doc.documentID, creatorUid: d["creatorUid"] as? String ?? "",
                videoId: d["videoId"] as? String, title: d["title"] as? String ?? "",
                scheduledAt: (d["scheduledAt"] as? Timestamp)?.dateValue() ?? Date(),
                platforms: d["platforms"] as? [String] ?? [],
                status: ScheduleStatus(rawValue: d["status"] as? String ?? "") ?? .draft,
                contentType: d["contentType"] as? String ?? "video"
            )
        }
        #endif
    }

    func schedulePost(creatorUid: String, title: String, videoId: String?, scheduledAt: Date, platforms: [String]) async throws -> String {
        guard AppConfig.Features.enableContentCalendar else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("content_calendar").document()
        try await ref.setData([
            "creatorUid": creatorUid, "title": title, "videoId": videoId as Any,
            "scheduledAt": Timestamp(date: scheduledAt), "platforms": platforms,
            "status": ScheduleStatus.scheduled.rawValue, "contentType": "video"
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func predictOptimalTimes(creatorUid: String) async throws {
        guard AppConfig.Features.enableContentCalendar else { return }
        struct Request: Encodable { let task: String; let creatorUid: String }
        struct RawSlot: Decodable { let day: Int; let hour: Int; let engagement: Double; let audience: Double }
        struct Raw: Decodable { let slots: [RawSlot]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .watchTimeOptimizer, path: "/predict",
            body: Request(task: "optimal_publish_times", creatorUid: creatorUid)
        )
        optimalSlots = (r.slots ?? []).map {
            OptimalTimeSlot(id: UUID().uuidString, dayOfWeek: $0.day, hour: $0.hour,
                          predictedEngagement: $0.engagement, audienceOnlinePercent: $0.audience)
        }
    }

    func reschedule(postId: String, newDate: Date) async throws {
        guard AppConfig.Features.enableContentCalendar else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("content_calendar").document(postId)
            .updateData(["scheduledAt": Timestamp(date: newDate)])
        #endif
    }
}
