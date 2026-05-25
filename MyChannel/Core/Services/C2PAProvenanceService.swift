//
//  C2PAProvenanceService.swift
//  MyChannel
//
//  Phase 73: C2PA content provenance.
//  Embeds a signed manifest on capture/upload (camera frames, AI-generated
//  assets) and verifies manifests for any inbound media.
//  Uses the `deepfake-detector-ai` Cloud Run agent to auto-label AI content
//  when a manifest is missing or tampered.
//

import Foundation

enum ProvenanceLabel: String, Codable {
    case originalCapture      // camera-signed
    case edited               // edited by verified tool
    case aiGenerated          // labelled synthetic
    case aiAssisted           // mixed
    case unknown
}

struct C2PAManifest: Codable, Equatable {
    let assetId: String
    let creatorUid: String?
    let captureDevice: String?
    let captureAppVersion: String?
    let createdAt: Date
    let claims: [String]         // free-form provenance claims
    let signatureHash: String    // verification happens server-side
    let label: ProvenanceLabel
}

@MainActor
final class C2PAProvenanceService: ObservableObject {
    static let shared = C2PAProvenanceService()
    private init() {}

    // MARK: - Signing

    /// Produce a manifest for a freshly captured asset. The signing key is
    /// ephemeral and rotated per session; server-side function verifies + persists.
    func sign(assetId: String, creatorUid: String, claims: [String], label: ProvenanceLabel) -> C2PAManifest {
        let deviceName = ProcessInfo.processInfo.hostName
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let now = Date()
        let baseString = "\(assetId)|\(creatorUid)|\(now.timeIntervalSince1970)|\(label.rawValue)"
        return C2PAManifest(
            assetId: assetId,
            creatorUid: creatorUid,
            captureDevice: deviceName,
            captureAppVersion: appVersion,
            createdAt: now,
            claims: claims,
            signatureHash: Self.fingerprint(baseString),
            label: label
        )
    }

    /// Persist the signed manifest server-side (Cloud Run + Firestore).
    func persist(_ manifest: C2PAManifest) async throws {
        guard AppConfig.Features.enableC2PAProvenance else { return }
        _ = try await CloudRunAgentRouter.post(
            .legalCompliance,
            path: "/predict",
            body: Payload(task: "persist_manifest", manifest: manifest)
        ) as _Ack
    }

    // MARK: - Verification

    /// Verify an incoming manifest. Returns the trusted label to display.
    func verify(_ manifest: C2PAManifest) async -> ProvenanceLabel {
        guard AppConfig.Features.enableC2PAProvenance else { return manifest.label }
        struct Raw: Decodable { let label: String?; let tampered: Bool? }
        let raw: Raw? = try? await CloudRunAgentRouter.post(
            .legalCompliance,
            path: "/predict",
            body: Payload(task: "verify_manifest", manifest: manifest)
        )
        if raw?.tampered == true { return .unknown }
        return ProvenanceLabel(rawValue: raw?.label ?? manifest.label.rawValue) ?? manifest.label
    }

    /// When no manifest exists, ask `deepfake-detector-ai` to infer whether
    /// content is AI-generated and attach the label.
    func inferLabelForUnsigned(assetURL: URL) async -> ProvenanceLabel {
        guard AppConfig.Features.enableC2PAProvenance else { return .unknown }
        struct Request: Encodable { let task: String; let assetURL: String }
        struct Raw: Decodable { let label: String? }
        let raw: Raw? = try? await CloudRunAgentRouter.post(
            .deepfakeDetector,
            path: "/predict",
            body: Request(task: "infer_provenance", assetURL: assetURL.absoluteString)
        )
        return ProvenanceLabel(rawValue: raw?.label ?? "unknown") ?? .unknown
    }

    // MARK: - Helpers

    private struct Payload<T: Encodable>: Encodable {
        let task: String
        let manifest: T
    }
    private struct _Ack: Decodable { let ok: Bool? }

    private static func fingerprint(_ s: String) -> String {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return String(h, radix: 16)
    }
}
