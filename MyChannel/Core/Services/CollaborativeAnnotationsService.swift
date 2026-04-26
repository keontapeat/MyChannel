//
//  CollaborativeAnnotationsService.swift
//  MyChannel
//
//  Phase 148: Collaborative Annotations.
//  Creator/viewer annotations, linked cards, interactive hotspots.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct VideoAnnotation: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let authorUid: String
    let type: AnnotationType
    let text: String
    let linkURL: URL?
    let timestampSec: Double
    let durationSec: Double
    let positionX: Double       // 0–1 normalized
    let positionY: Double
    let style: AnnotationStyle
    let approved: Bool
    let createdAt: Date
}

enum AnnotationType: String, Codable, CaseIterable {
    case text, link, hotspot, poll, product
}

enum AnnotationStyle: String, Codable, CaseIterable {
    case bubble, banner, minimal, highlight, card
}

struct Hotspot: Codable, Identifiable, Equatable {
    let id: String
    let annotationId: String
    let shape: HotspotShape
    let targetURL: URL?
    let targetVideoId: String?
    let targetTimeSec: Double?
}

enum HotspotShape: String, Codable { case circle, rect, custom }

// MARK: - Service

@MainActor
final class CollaborativeAnnotationsService: ObservableObject {
    static let shared = CollaborativeAnnotationsService()
    private init() {}

    @Published private(set) var annotations: [VideoAnnotation] = []
    @Published var visibleAnnotations: [VideoAnnotation] = []
    @Published var annotationsEnabled: Bool = true

    func loadAnnotations(videoId: String) async throws {
        guard AppConfig.Features.enableCollaborativeAnnotations else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("video_annotations")
            .whereField("videoId", isEqualTo: videoId)
            .whereField("approved", isEqualTo: true)
            .order(by: "timestampSec")
            .getDocuments()
        annotations = snap.documents.compactMap { doc in
            let d = doc.data()
            return VideoAnnotation(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                authorUid: d["authorUid"] as? String ?? "",
                type: AnnotationType(rawValue: d["type"] as? String ?? "") ?? .text,
                text: d["text"] as? String ?? "",
                linkURL: (d["linkURL"] as? String).flatMap(URL.init(string:)),
                timestampSec: d["timestampSec"] as? Double ?? 0,
                durationSec: d["durationSec"] as? Double ?? 5,
                positionX: d["positionX"] as? Double ?? 0.5,
                positionY: d["positionY"] as? Double ?? 0.1,
                style: AnnotationStyle(rawValue: d["style"] as? String ?? "") ?? .bubble,
                approved: true,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func addAnnotation(videoId: String, authorUid: String, type: AnnotationType, text: String, timestampSec: Double, positionX: Double, positionY: Double) async throws -> String {
        guard AppConfig.Features.enableCollaborativeAnnotations else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("video_annotations").document()
        try await ref.setData([
            "videoId": videoId, "authorUid": authorUid, "type": type.rawValue,
            "text": text, "timestampSec": timestampSec, "durationSec": 5.0,
            "positionX": positionX, "positionY": positionY,
            "style": AnnotationStyle.bubble.rawValue, "approved": false,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }

    func updateVisible(currentTime: Double) {
        guard AppConfig.Features.enableCollaborativeAnnotations, annotationsEnabled else {
            visibleAnnotations = []; return
        }
        visibleAnnotations = annotations.filter {
            currentTime >= $0.timestampSec && currentTime <= $0.timestampSec + $0.durationSec
        }
    }

    func approveAnnotation(annotationId: String) async throws {
        guard AppConfig.Features.enableCollaborativeAnnotations else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("video_annotations").document(annotationId)
            .updateData(["approved": true])
        #endif
    }
}
