//
//  MultiChannelCMSService.swift
//  MyChannel
//
//  Phase 107: Multi-Channel CMS.
//  Shared content calendar, batch metadata edits, coordinated
//  multi-channel publish across team workspaces.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CMSScheduleEntry: Codable, Identifiable, Equatable {
    let id: String
    let workspaceId: String
    let videoId: String
    let title: String
    let channelIds: [String]
    let scheduledAt: Date
    let status: CMSPublishStatus
    let createdByUid: String
}

enum CMSPublishStatus: String, Codable {
    case draft, scheduled, publishing, published, failed
}

struct BatchMetadataEdit: Codable {
    let videoIds: [String]
    let updates: MetadataUpdates
}

struct MetadataUpdates: Codable {
    let title: String?
    let description: String?
    let tags: [String]?
    let category: String?
    let visibility: String?
}

// MARK: - Service

@MainActor
final class MultiChannelCMSService: ObservableObject {
    static let shared = MultiChannelCMSService()
    private init() {}

    @Published private(set) var calendar: [CMSScheduleEntry] = []

    func loadCalendar(workspaceId: String) async throws {
        guard AppConfig.Features.enableMultiChannelCMS else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("cms_schedules")
            .whereField("workspaceId", isEqualTo: workspaceId)
            .order(by: "scheduledAt")
            .getDocuments()
        calendar = snap.documents.compactMap { doc in
            let d = doc.data()
            return CMSScheduleEntry(
                id: doc.documentID,
                workspaceId: d["workspaceId"] as? String ?? "",
                videoId: d["videoId"] as? String ?? "",
                title: d["title"] as? String ?? "",
                channelIds: d["channelIds"] as? [String] ?? [],
                scheduledAt: (d["scheduledAt"] as? Timestamp)?.dateValue() ?? Date(),
                status: CMSPublishStatus(rawValue: d["status"] as? String ?? "") ?? .draft,
                createdByUid: d["createdByUid"] as? String ?? ""
            )
        }
        #endif
    }

    func schedulePost(workspaceId: String, videoId: String, title: String, channelIds: [String], scheduledAt: Date, creatorUid: String) async throws {
        guard AppConfig.Features.enableMultiChannelCMS else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("cms_schedules").document()
            .setData([
                "workspaceId": workspaceId,
                "videoId": videoId,
                "title": title,
                "channelIds": channelIds,
                "scheduledAt": Timestamp(date: scheduledAt),
                "status": CMSPublishStatus.scheduled.rawValue,
                "createdByUid": creatorUid
            ])
        #endif
    }

    func batchUpdateMetadata(_ edit: BatchMetadataEdit) async throws {
        guard AppConfig.Features.enableMultiChannelCMS else { return }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        for videoId in edit.videoIds {
            let ref = db.collection("videos").document(videoId)
            var updates: [String: Any] = [:]
            if let t = edit.updates.title { updates["title"] = t }
            if let d = edit.updates.description { updates["description"] = d }
            if let tags = edit.updates.tags { updates["tags"] = tags }
            if let c = edit.updates.category { updates["category"] = c }
            if let v = edit.updates.visibility { updates["visibility"] = v }
            if !updates.isEmpty { batch.updateData(updates, forDocument: ref) }
        }
        try await batch.commit()
        #endif
    }

    func coordinatedPublish(scheduleId: String) async throws {
        guard AppConfig.Features.enableMultiChannelCMS else { return }
        struct Request: Encodable { let task: String; let scheduleId: String }
        struct Raw: Decodable { let status: String? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent,
            path: "/predict",
            body: Request(task: "coordinated_publish", scheduleId: scheduleId)
        )
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("cms_schedules").document(scheduleId)
            .updateData(["status": CMSPublishStatus.published.rawValue])
        #endif
    }
}
