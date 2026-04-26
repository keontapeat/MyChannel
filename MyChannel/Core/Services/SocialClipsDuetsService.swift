//
//  SocialClipsDuetsService.swift
//  MyChannel
//
//  Phase 124: Social Clips & Duets.
//  Side-by-side reaction videos, stitch editing, attribution chain tracking.
//  Uses `video-editor-ai-v2` for clip processing.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct DuetProject: Codable, Identifiable, Equatable {
    let id: String
    let originalVideoId: String
    let reactorUid: String
    let layout: DuetLayout
    let status: DuetStatus
    let outputVideoId: String?
    let createdAt: Date
}

enum DuetLayout: String, Codable, CaseIterable {
    case sideBySide, topBottom, pictureInPicture, greenScreen
}

enum DuetStatus: String, Codable { case recording, processing, published, failed }

struct StitchClip: Codable, Identifiable, Equatable {
    let id: String
    let sourceVideoId: String
    let startSec: Double
    let endSec: Double
    let creatorUid: String
}

struct AttributionChain: Codable {
    let originalVideoId: String
    let originalCreatorUid: String
    let derivativeIds: [String]
    let totalViews: Int
}

// MARK: - Service

@MainActor
final class SocialClipsDuetsService: ObservableObject {
    static let shared = SocialClipsDuetsService()
    private init() {}

    @Published private(set) var duetProjects: [DuetProject] = []
    @Published private(set) var attributionChain: AttributionChain?

    func loadDuets(uid: String) async throws {
        guard AppConfig.Features.enableSocialClipsDuets else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("duet_projects").whereField("reactorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true).getDocuments()
        duetProjects = snap.documents.compactMap { doc in
            let d = doc.data()
            return DuetProject(
                id: doc.documentID, originalVideoId: d["originalVideoId"] as? String ?? "",
                reactorUid: d["reactorUid"] as? String ?? "",
                layout: DuetLayout(rawValue: d["layout"] as? String ?? "") ?? .sideBySide,
                status: DuetStatus(rawValue: d["status"] as? String ?? "") ?? .recording,
                outputVideoId: d["outputVideoId"] as? String,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func createDuet(originalVideoId: String, reactorUid: String, layout: DuetLayout) async throws -> String {
        guard AppConfig.Features.enableSocialClipsDuets else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("duet_projects").document()
        try await ref.setData([
            "originalVideoId": originalVideoId, "reactorUid": reactorUid,
            "layout": layout.rawValue, "status": DuetStatus.recording.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func processDuet(projectId: String, reactorVideoURL: String) async throws {
        guard AppConfig.Features.enableSocialClipsDuets else { return }
        struct Request: Encodable { let task: String; let projectId: String; let reactorVideoURL: String }
        struct Raw: Decodable { let output_video_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "process_duet", projectId: projectId, reactorVideoURL: reactorVideoURL),
            timeout: 120
        )
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("duet_projects").document(projectId)
            .updateData(["status": DuetStatus.published.rawValue, "outputVideoId": r.output_video_id as Any])
        #endif
    }

    func createStitch(clips: [StitchClip], creatorUid: String) async throws -> String {
        guard AppConfig.Features.enableSocialClipsDuets else { return "" }
        struct ClipPayload: Encodable { let videoId: String; let start: Double; let end: Double }
        struct Request: Encodable { let task: String; let clips: [ClipPayload]; let creatorUid: String }
        struct Raw: Decodable { let output_video_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "stitch_clips", clips: clips.map { ClipPayload(videoId: $0.sourceVideoId, start: $0.startSec, end: $0.endSec) }, creatorUid: creatorUid),
            timeout: 120
        )
        return r.output_video_id ?? ""
    }

    func loadAttribution(videoId: String) async throws {
        guard AppConfig.Features.enableSocialClipsDuets else { return }
        #if canImport(FirebaseFirestore)
        let doc = try await Firestore.firestore().collection("attribution_chains").document(videoId).getDocument()
        guard let d = doc.data() else { return }
        attributionChain = AttributionChain(
            originalVideoId: d["originalVideoId"] as? String ?? videoId,
            originalCreatorUid: d["originalCreatorUid"] as? String ?? "",
            derivativeIds: d["derivativeIds"] as? [String] ?? [],
            totalViews: d["totalViews"] as? Int ?? 0
        )
        #endif
    }
}
