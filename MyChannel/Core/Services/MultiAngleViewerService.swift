//
//  MultiAngleViewerService.swift
//  MyChannel
//
//  Phase 155: Multi-Angle Viewer.
//  Synchronized multi-camera feeds, viewer-selectable angles.
//  Uses `super-ai-team` Cloud Run for angle detection.
//

import Foundation
import AVFoundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct CameraAngle: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String       // parent video
    let label: String         // "Main", "Wide", "Close-up", "BTS"
    let streamURL: URL?
    let thumbnailURL: URL?
    let isDefault: Bool
    let sortOrder: Int
}

struct AngleSyncState: Equatable {
    var activeAngleId: String
    var syncTimeSec: Double
    var isPlaying: Bool
}

// MARK: - Service

@MainActor
final class MultiAngleViewerService: ObservableObject {
    static let shared = MultiAngleViewerService()
    private init() {}

    @Published private(set) var angles: [CameraAngle] = []
    @Published var syncState = AngleSyncState(activeAngleId: "", syncTimeSec: 0, isPlaying: false)
    @Published var isMultiAngle: Bool = false

    func loadAngles(videoId: String) async throws {
        guard AppConfig.Features.enableMultiAngleViewer else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("camera_angles").whereField("videoId", isEqualTo: videoId)
            .order(by: "sortOrder").getDocuments()
        angles = snap.documents.compactMap { doc in
            let d = doc.data()
            return CameraAngle(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                label: d["label"] as? String ?? "", streamURL: (d["streamURL"] as? String).flatMap(URL.init(string:)),
                thumbnailURL: (d["thumbnailURL"] as? String).flatMap(URL.init(string:)),
                isDefault: d["isDefault"] as? Bool ?? false, sortOrder: d["sortOrder"] as? Int ?? 0
            )
        }
        isMultiAngle = angles.count > 1
        if let defaultAngle = angles.first(where: { $0.isDefault }) ?? angles.first {
            syncState.activeAngleId = defaultAngle.id
        }
        #endif
    }

    func switchAngle(to angleId: String, currentTimeSec: Double, player: AVPlayer?) {
        guard AppConfig.Features.enableMultiAngleViewer else { return }
        guard let angle = angles.first(where: { $0.id == angleId }),
              let url = angle.streamURL else { return }
        syncState.activeAngleId = angleId
        syncState.syncTimeSec = currentTimeSec
        let wasPlaying = player?.rate != 0
        let item = AVPlayerItem(url: url)
        player?.replaceCurrentItem(with: item)
        let time = CMTime(seconds: currentTimeSec, preferredTimescale: 600)
        player?.seek(to: time) { _ in
            if wasPlaying { player?.play() }
        }
    }

    func detectAngles(videoId: String) async throws -> [String] {
        guard AppConfig.Features.enableMultiAngleViewer else { return [] }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let angles: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "detect_camera_angles", videoId: videoId), timeout: 30
        )
        return r.angles ?? []
    }
}
