//
//  GameClipSDKService.swift
//  MyChannel
//
//  Phase 83: Game Clip Capture SDK.
//  Endpoints game studios (iOS / Android) call to push highlight clips
//  directly to MyChannel. This file is the iOS-side reference implementation
//  studios can embed. Ships as a header-only target published via SPM.
//

import Foundation

public struct GameClipMetadata: Codable {
    public let gameId: String
    public let studioId: String
    public let playerUid: String?
    public let sessionId: String?
    public let gameTitle: String
    public let captureDurationSeconds: Double
    public let platform: String
    public let triggerReason: String   // "kill_streak", "quest_complete", "clutch", "user_requested"
}

public struct GameClipUploadResult: Codable {
    public let clipId: String
    public let ingestURL: URL            // pre-signed PUT URL for the .mp4
    public let watchURL: URL             // final MyChannel URL after transcode
}

public final class GameClipSDK {
    public static let shared = GameClipSDK()
    private init() {}

    /// Configure with the studio's client ID. Obtained via Developer Portal (Phase 70).
    public func configure(clientId: String, apiKey: String) {
        self.clientId = clientId
        self.apiKey = apiKey
    }

    public private(set) var clientId: String = ""
    public private(set) var apiKey: String = ""

    private let ingestBase = "https://clips-ingest.mychannel.live/v1"

    /// Request a pre-signed upload slot. Studio then does a PUT of the .mp4 bytes.
    public func reserveUploadSlot(_ metadata: GameClipMetadata) async throws -> GameClipUploadResult {
        guard AppConfig.Features.enableGameClipSDK else { throw SDKError.disabled }
        guard !clientId.isEmpty, !apiKey.isEmpty else { throw SDKError.notConfigured }
        guard let url = URL(string: "\(ingestBase)/reserve") else { throw SDKError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(clientId, forHTTPHeaderField: "X-MyChannel-Client-Id")
        req.httpBody = try JSONEncoder().encode(metadata)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "ingest_error"
            throw SDKError.http((resp as? HTTPURLResponse)?.statusCode ?? 0, msg)
        }
        return try JSONDecoder().decode(GameClipUploadResult.self, from: data)
    }

    /// PUT the mp4 bytes. Caller can chunk this themselves for resumable uploads.
    public func uploadClip(fileURL: URL, to ingestURL: URL) async throws {
        var req = URLRequest(url: ingestURL)
        req.httpMethod = "PUT"
        req.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        let data = try Data(contentsOf: fileURL)
        let (_, resp) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SDKError.http((resp as? HTTPURLResponse)?.statusCode ?? 0, "upload_failed")
        }
    }

    /// Mark the upload complete so MyChannel can transcode + publish.
    public func finalize(clipId: String) async throws -> URL {
        guard let url = URL(string: "\(ingestBase)/clips/\(clipId)/finalize") else { throw SDKError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(clientId, forHTTPHeaderField: "X-MyChannel-Client-Id")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "finalize_error"
            throw SDKError.http((resp as? HTTPURLResponse)?.statusCode ?? 0, msg)
        }
        struct Raw: Decodable { let watch_url: String }
        let decoded = try JSONDecoder().decode(Raw.self, from: data)
        guard let watch = URL(string: decoded.watch_url) else { throw SDKError.badURL }
        return watch
    }

    public enum SDKError: LocalizedError {
        case disabled, notConfigured, badURL, http(Int, String)
        public var errorDescription: String? {
            switch self {
            case .disabled: return "Game Clip SDK is disabled on this build."
            case .notConfigured: return "Call GameClipSDK.shared.configure(clientId:apiKey:) first."
            case .badURL: return "Invalid ingest URL."
            case .http(let code, let msg): return "Ingest HTTP \(code): \(msg)"
            }
        }
    }
}
