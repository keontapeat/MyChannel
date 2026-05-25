//
//  CrossPlatformSyndicationV2Service.swift
//  MyChannel
//
//  Phase 177: Cross-Platform Syndication v2.
//  Auto-publish to YouTube/TikTok/Instagram, format adaptation.
//  Uses `shorts-optimizer-ai` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct SyndicationTarget: Codable, Identifiable, Equatable {
    let id: String
    let platform: String
    let accountName: String
    let isConnected: Bool
    let autoPublish: Bool
}

struct SyndicationJob: Codable, Identifiable {
    let id: String
    let videoId: String
    let platform: String
    let adaptedFormat: String
    let status: String
    let externalURL: URL?
    let publishedAt: Date?
}

// MARK: - Service

@MainActor
final class CrossPlatformSyndicationV2Service: ObservableObject {
    static let shared = CrossPlatformSyndicationV2Service()
    private init() {}

    @Published private(set) var targets: [SyndicationTarget] = []
    @Published private(set) var jobs: [SyndicationJob] = []

    func loadTargets(creatorUid: String) async throws {
        guard AppConfig.Features.enableCrossPlatformSyndicationV2 else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("syndication_targets").whereField("creatorUid", isEqualTo: creatorUid).getDocuments()
        targets = snap.documents.compactMap { doc in
            let d = doc.data()
            return SyndicationTarget(id: doc.documentID, platform: d["platform"] as? String ?? "",
                                    accountName: d["accountName"] as? String ?? "",
                                    isConnected: d["isConnected"] as? Bool ?? false,
                                    autoPublish: d["autoPublish"] as? Bool ?? false)
        }
        #endif
    }

    func syndicate(videoId: String, platforms: [String]) async throws {
        guard AppConfig.Features.enableCrossPlatformSyndicationV2 else { return }
        for platform in platforms {
            struct Request: Encodable { let task: String; let videoId: String; let platform: String }
            struct Raw: Decodable { let job_id: String?; let format: String?; let status: String? }
            let r: Raw = try await CloudRunAgentRouter.post(
                .shortsOptimizer, path: "/predict",
                body: Request(task: "syndicate", videoId: videoId, platform: platform), timeout: 60
            )
            jobs.append(SyndicationJob(id: r.job_id ?? UUID().uuidString, videoId: videoId,
                                       platform: platform, adaptedFormat: r.format ?? "original",
                                       status: r.status ?? "queued", externalURL: nil, publishedAt: nil))
        }
    }

    func adaptFormat(videoId: String, targetPlatform: String) async throws -> String {
        guard AppConfig.Features.enableCrossPlatformSyndicationV2 else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let platform: String }
        struct Raw: Decodable { let adapted_url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .shortsOptimizer, path: "/predict",
            body: Request(task: "adapt_format", videoId: videoId, platform: targetPlatform), timeout: 60
        )
        return r.adapted_url ?? ""
    }
}
