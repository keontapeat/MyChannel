//
//  AutoLocalizationStudioService.swift
//  MyChannel
//
//  Phase 115: Auto-Localization Studio.
//  One-tap dubbing/subtitles/region-specific thumbnails, quality scoring
//  before publish. Uses `translation-ai-v2` + `voice-ai`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct LocalizationJob: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let sourceLocale: String
    let targetLocales: [String]
    let tasks: [LocalizationTask]
    let status: LocalizationJobStatus
    let qualityScore: Double?     // 0–1 after scoring
    let createdAt: Date
}

enum LocalizationJobStatus: String, Codable {
    case queued, processing, review, published, failed
}

struct LocalizationTask: Codable, Identifiable, Equatable {
    let id: String
    let type: LocalizationType
    let targetLocale: String
    let status: String
    let outputURL: URL?
}

enum LocalizationType: String, Codable, CaseIterable {
    case dubbing, subtitles, thumbnail, titleDescription
}

struct QualityReport: Codable {
    let overallScore: Double
    let perLocale: [String: Double]
    let issues: [String]
}

// MARK: - Service

@MainActor
final class AutoLocalizationStudioService: ObservableObject {
    static let shared = AutoLocalizationStudioService()
    private init() {}

    @Published private(set) var jobs: [LocalizationJob] = []
    @Published private(set) var latestQuality: QualityReport?

    func loadJobs(creatorUid: String) async throws {
        guard AppConfig.Features.enableAutoLocalizationStudio else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("localization_jobs")
            .whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .getDocuments()
        jobs = snap.documents.compactMap { doc in
            try? doc.data(as: LocalizationJob.self)
        }
        #endif
    }

    func generateDubbing(videoId: String, sourceLocale: String, targetLocales: [String]) async throws -> String {
        guard AppConfig.Features.enableAutoLocalizationStudio else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let source: String; let targets: [String] }
        struct Raw: Decodable { let job_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .voiceAI,
            path: "/predict",
            body: Request(task: "generate_dubbing", videoId: videoId, source: sourceLocale, targets: targetLocales),
            timeout: 60
        )
        return r.job_id ?? ""
    }

    func generateSubtitles(videoId: String, targetLocales: [String]) async throws -> String {
        guard AppConfig.Features.enableAutoLocalizationStudio else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let targets: [String] }
        struct Raw: Decodable { let job_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .translationAI,
            path: "/predict",
            body: Request(task: "generate_subtitles", videoId: videoId, targets: targetLocales),
            timeout: 60
        )
        return r.job_id ?? ""
    }

    func regionalizeThumbnail(videoId: String, targetLocales: [String]) async throws -> String {
        guard AppConfig.Features.enableAutoLocalizationStudio else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let targets: [String] }
        struct Raw: Decodable { let job_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .thumbnailGen,
            path: "/predict",
            body: Request(task: "regionalize_thumbnail", videoId: videoId, targets: targetLocales)
        )
        return r.job_id ?? ""
    }

    func scoreQuality(jobId: String) async throws {
        guard AppConfig.Features.enableAutoLocalizationStudio else { return }
        struct Request: Encodable { let task: String; let jobId: String }
        struct RawLocale: Decodable { let locale: String; let score: Double }
        struct Raw: Decodable { let overall: Double?; let per_locale: [RawLocale]?; let issues: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .translationAI,
            path: "/predict",
            body: Request(task: "score_quality", jobId: jobId)
        )
        var perLocale: [String: Double] = [:]
        for l in r.per_locale ?? [] { perLocale[l.locale] = l.score }
        latestQuality = QualityReport(overallScore: r.overall ?? 0, perLocale: perLocale, issues: r.issues ?? [])
    }
}
