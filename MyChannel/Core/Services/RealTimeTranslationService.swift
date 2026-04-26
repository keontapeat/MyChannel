//
//  RealTimeTranslationService.swift
//  MyChannel
//
//  Phase 134: Real-Time Translation Overlay.
//  Live subtitle rendering in viewer's language during live streams.
//  Uses `translation-ai-v2` + `multi-language-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct TranslationSession: Codable, Identifiable {
    let id: String
    let liveStreamId: String
    let sourceLocale: String
    let targetLocales: [String]
    let status: TranslationSessionStatus
    let startedAt: Date
}

enum TranslationSessionStatus: String, Codable { case active, paused, ended }

struct LiveSubtitleChunk: Codable, Identifiable {
    let id: String
    let sessionId: String
    let sourceText: String
    let translations: [String: String]  // locale → translated text
    let timestampSec: Double
    let confidence: Double
}

struct TranslationQuality: Codable {
    let locale: String
    let bleuScore: Double
    let latencyMs: Int
    let errorRate: Double
}

// MARK: - Service

@MainActor
final class RealTimeTranslationService: ObservableObject {
    static let shared = RealTimeTranslationService()
    private init() {}

    @Published private(set) var activeSession: TranslationSession?
    @Published private(set) var latestChunks: [LiveSubtitleChunk] = []
    @Published private(set) var qualityMetrics: [TranslationQuality] = []

    func startSession(liveStreamId: String, sourceLocale: String, targetLocales: [String]) async throws -> String {
        guard AppConfig.Features.enableRealTimeTranslation else { return "" }
        struct Request: Encodable { let task: String; let streamId: String; let source: String; let targets: [String] }
        struct Raw: Decodable { let session_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .translationAI, path: "/predict",
            body: Request(task: "start_live_translation", streamId: liveStreamId, source: sourceLocale, targets: targetLocales)
        )
        let sessionId = r.session_id ?? UUID().uuidString
        activeSession = TranslationSession(
            id: sessionId, liveStreamId: liveStreamId, sourceLocale: sourceLocale,
            targetLocales: targetLocales, status: .active, startedAt: Date()
        )
        return sessionId
    }

    func translateChunk(sessionId: String, sourceText: String, timestampSec: Double) async throws -> LiveSubtitleChunk {
        guard AppConfig.Features.enableRealTimeTranslation else {
            return LiveSubtitleChunk(id: "", sessionId: sessionId, sourceText: sourceText, translations: [:], timestampSec: timestampSec, confidence: 0)
        }
        struct Request: Encodable { let task: String; let sessionId: String; let text: String; let timestamp: Double }
        struct Raw: Decodable { let translations: [String: String]?; let confidence: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .multiLanguageAI, path: "/predict",
            body: Request(task: "translate_chunk", sessionId: sessionId, text: sourceText, timestamp: timestampSec),
            timeout: 5
        )
        let chunk = LiveSubtitleChunk(
            id: UUID().uuidString, sessionId: sessionId, sourceText: sourceText,
            translations: r.translations ?? [:], timestampSec: timestampSec, confidence: r.confidence ?? 0
        )
        latestChunks.append(chunk)
        if latestChunks.count > 100 { latestChunks.removeFirst(50) }
        return chunk
    }

    func endSession(sessionId: String) async throws {
        guard AppConfig.Features.enableRealTimeTranslation else { return }
        struct Request: Encodable { let task: String; let sessionId: String }
        struct Raw: Decodable { let status: String? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .translationAI, path: "/predict",
            body: Request(task: "end_live_translation", sessionId: sessionId)
        )
        activeSession = nil
        latestChunks.removeAll()
    }

    func checkQuality(sessionId: String) async throws {
        guard AppConfig.Features.enableRealTimeTranslation else { return }
        struct Request: Encodable { let task: String; let sessionId: String }
        struct RawQuality: Decodable { let locale: String; let bleu: Double; let latency_ms: Int; let error_rate: Double }
        struct Raw: Decodable { let quality: [RawQuality]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .translationAI, path: "/predict",
            body: Request(task: "translation_quality", sessionId: sessionId)
        )
        qualityMetrics = (r.quality ?? []).map {
            TranslationQuality(locale: $0.locale, bleuScore: $0.bleu, latencyMs: $0.latency_ms, errorRate: $0.error_rate)
        }
    }
}
