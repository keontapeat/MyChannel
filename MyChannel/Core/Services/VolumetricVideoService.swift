//
//  VolumetricVideoService.swift
//  MyChannel
//
//  Phase 132: 3D & Volumetric Video.
//  USDZ/glTF ingest, spatial rendering, Vision Pro native playback.
//  Uses `vr-ar-ai-v2` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct VolumetricAsset: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let format: VolumetricFormat
    let assetURL: URL?
    let fileSizeMB: Double
    let durationSec: Double
    let spatialMetadata: SpatialMeta?
    let createdAt: Date
}

enum VolumetricFormat: String, Codable, CaseIterable { case usdz, gltf, reality, mv_hevc = "mv-hevc" }

struct SpatialMeta: Codable, Equatable {
    let stereoMode: String       // "side-by-side", "top-bottom", "multiview"
    let fieldOfViewDeg: Double
    let depthMapAvailable: Bool
}

struct ConversionJob: Codable, Identifiable {
    let id: String
    let inputURL: URL
    let outputFormat: VolumetricFormat
    let status: String
    let outputURL: URL?
    let progress: Double
}

// MARK: - Service

@MainActor
final class VolumetricVideoService: ObservableObject {
    static let shared = VolumetricVideoService()
    private init() {}

    @Published private(set) var assets: [VolumetricAsset] = []
    @Published private(set) var conversionJob: ConversionJob?

    func loadAssets(videoId: String) async throws {
        guard AppConfig.Features.enableVolumetricVideo else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("volumetric_assets").whereField("videoId", isEqualTo: videoId).getDocuments()
        assets = snap.documents.compactMap { doc in
            let d = doc.data()
            return VolumetricAsset(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                format: VolumetricFormat(rawValue: d["format"] as? String ?? "") ?? .usdz,
                assetURL: (d["assetURL"] as? String).flatMap(URL.init(string:)),
                fileSizeMB: d["fileSizeMB"] as? Double ?? 0,
                durationSec: d["durationSec"] as? Double ?? 0,
                spatialMetadata: nil,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func ingest(videoId: String, inputURL: URL, format: VolumetricFormat) async throws -> String {
        guard AppConfig.Features.enableVolumetricVideo else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let inputURL: String; let format: String }
        struct Raw: Decodable { let job_id: String?; let status: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .vrArAIv2, path: "/predict",
            body: Request(task: "ingest_volumetric", videoId: videoId, inputURL: inputURL.absoluteString, format: format.rawValue),
            timeout: 120
        )
        return r.job_id ?? ""
    }

    func convertFormat(inputURL: URL, outputFormat: VolumetricFormat) async throws {
        guard AppConfig.Features.enableVolumetricVideo else { return }
        struct Request: Encodable { let task: String; let inputURL: String; let outputFormat: String }
        struct Raw: Decodable { let job_id: String?; let output_url: String?; let status: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .vrArAIv2, path: "/predict",
            body: Request(task: "convert_volumetric", inputURL: inputURL.absoluteString, outputFormat: outputFormat.rawValue),
            timeout: 120
        )
        conversionJob = ConversionJob(
            id: r.job_id ?? UUID().uuidString, inputURL: inputURL, outputFormat: outputFormat,
            status: r.status ?? "processing", outputURL: r.output_url.flatMap(URL.init(string:)), progress: 0
        )
    }

    func generateSpatialPreview(videoId: String) async throws -> URL? {
        guard AppConfig.Features.enableVolumetricVideo else { return nil }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let preview_url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .vrArAIv2, path: "/predict",
            body: Request(task: "spatial_preview", videoId: videoId)
        )
        return r.preview_url.flatMap(URL.init(string:))
    }
}
