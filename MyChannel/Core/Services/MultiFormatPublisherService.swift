//
//  MultiFormatPublisherService.swift
//  MyChannel
//
//  Phase 127: Multi-Format Publisher.
//  One upload → auto-generate Flick, Story, thumbnail, community post, podcast clip.
//  Uses `shorts-optimizer-ai` + `thumbnail-gen-v2`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct MultiFormatJob: Codable, Identifiable, Equatable {
    let id: String
    let sourceVideoId: String
    let creatorUid: String
    let formats: [FormatOutput]
    let status: MultiFormatStatus
    let createdAt: Date
}

enum MultiFormatStatus: String, Codable { case queued, processing, completed, failed }

struct FormatOutput: Codable, Identifiable, Equatable {
    let id: String
    let type: OutputFormat
    let outputId: String?
    let outputURL: URL?
    let status: String
}

enum OutputFormat: String, Codable, CaseIterable {
    case flick, story, thumbnail, communityPost, podcastClip
}

// MARK: - Service

@MainActor
final class MultiFormatPublisherService: ObservableObject {
    static let shared = MultiFormatPublisherService()
    private init() {}

    @Published private(set) var currentJob: MultiFormatJob?
    @Published private(set) var jobs: [MultiFormatJob] = []

    func generateAll(sourceVideoId: String, creatorUid: String, formats: [OutputFormat]? = nil) async throws -> String {
        guard AppConfig.Features.enableMultiFormatPublisher else { return "" }
        let targetFormats = formats ?? OutputFormat.allCases
        struct FormatReq: Encodable { let type: String }
        struct Request: Encodable { let task: String; let videoId: String; let formats: [FormatReq] }
        struct RawOutput: Decodable { let type: String; let output_id: String?; let url: String?; let status: String }
        struct Raw: Decodable { let job_id: String?; let outputs: [RawOutput]? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .shortsOptimizer, path: "/predict",
            body: Request(task: "multi_format_publish", videoId: sourceVideoId,
                         formats: targetFormats.map { FormatReq(type: $0.rawValue) }),
            timeout: 120
        )

        let job = MultiFormatJob(
            id: r.job_id ?? UUID().uuidString, sourceVideoId: sourceVideoId, creatorUid: creatorUid,
            formats: (r.outputs ?? []).map {
                FormatOutput(id: UUID().uuidString, type: OutputFormat(rawValue: $0.type) ?? .flick,
                           outputId: $0.output_id, outputURL: $0.url.flatMap(URL.init(string:)), status: $0.status)
            },
            status: .processing, createdAt: Date()
        )
        currentJob = job

        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("multi_format_jobs").document(job.id).setData([
            "sourceVideoId": sourceVideoId, "creatorUid": creatorUid,
            "formatCount": targetFormats.count, "status": "processing",
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
        return job.id
    }

    func loadJobs(creatorUid: String) async throws {
        guard AppConfig.Features.enableMultiFormatPublisher else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("multi_format_jobs").whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true).limit(to: 20).getDocuments()
        jobs = snap.documents.compactMap { doc in
            let d = doc.data()
            return MultiFormatJob(
                id: doc.documentID, sourceVideoId: d["sourceVideoId"] as? String ?? "",
                creatorUid: d["creatorUid"] as? String ?? "", formats: [],
                status: MultiFormatStatus(rawValue: d["status"] as? String ?? "") ?? .queued,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func generateThumbnailVariants(videoId: String) async throws -> [URL] {
        guard AppConfig.Features.enableMultiFormatPublisher else { return [] }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let urls: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .thumbnailGen, path: "/predict",
            body: Request(task: "thumbnail_variants", videoId: videoId)
        )
        return (r.urls ?? []).compactMap(URL.init(string:))
    }
}
