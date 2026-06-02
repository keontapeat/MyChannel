//
//  UniversityVideoService.swift
//  MyChannel
//
//  Bridges real Firestore `videos` into the University experience.
//  Maps platform Videos → UniversityVideo, grouping them by career path using
//  the AI categorization keywords. Returns real content when it exists and an
//  empty result otherwise (callers decide whether to show an empty state),
//  so the dashboard never shows fabricated "Lesson 1-10" rows.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UniversityVideoService: ObservableObject {
    static let shared = UniversityVideoService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    /// Fetch recent public videos and map them to UniversityVideo, tagged with
    /// the career paths whose keywords match the title/description.
    func fetchUniversityVideos(limit: Int = 60) async -> [UniversityVideo] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            var results: [UniversityVideo] = []
            for doc in snap.documents {
                let d = doc.data()

                let visibilityRaw = (d["visibility"] as? String)?.lowercased() ?? ""
                let isPublicField = (d["isPublic"] as? Bool) ?? true
                let isPublic = visibilityRaw == "public" || (visibilityRaw.isEmpty && isPublicField)
                guard isPublic else { continue }

                let title = d["title"] as? String ?? ""
                let description = d["description"] as? String ?? ""
                let tags = (d["tags"] as? [String]) ?? []
                guard !title.isEmpty else { continue }

                let matchedPaths = matchCareerPaths(title: title, description: description, tags: tags)
                guard !matchedPaths.isEmpty else { continue } // only surface educational content

                let thumbnail = (d["thumbnailURL"] as? String) ?? (d["thumbnailUrl"] as? String) ?? ""
                let duration = (d["duration"] as? Double) ?? (d["durationSeconds"] as? Double) ?? 0
                let creatorId = d["userId"] as? String ?? ""
                let creatorName = d["creatorDisplayName"] as? String ?? d["creatorName"] as? String ?? "Creator"
                let creatorAvatar = d["creatorProfileImage"] as? String ?? d["creatorAvatarURL"] as? String ?? ""

                let skillTags = matchedPaths
                    .compactMap { CareerPath.getCareerPath(byId: $0) }
                    .flatMap { $0.skillTags }
                    .reduce(into: [String]()) { acc, s in if !acc.contains(s) { acc.append(s) } }

                let video = UniversityVideo(
                    id: doc.documentID,
                    videoId: doc.documentID,
                    title: title,
                    thumbnailURL: thumbnail,
                    duration: duration,
                    creatorId: creatorId,
                    creatorName: creatorName,
                    creatorAvatarURL: creatorAvatar,
                    careerPaths: matchedPaths,
                    skillTags: Array(skillTags.prefix(4)),
                    difficultyLevel: .intermediate,
                    isUniversityContent: true,
                    certificateEligible: true,
                    aiCategorizationScore: 0.85,
                    watchProgress: 0,
                    lastWatchedAt: nil,
                    aiVerificationScore: nil,
                    completed: false
                )
                results.append(video)
            }
            return results
        } catch {
            print("⚠️ [UniversityVideoService] fetch failed: \(error.localizedDescription)")
        }
        #endif
        return []
    }

    /// Group University videos by career path id.
    func groupByCareerPath(_ videos: [UniversityVideo]) -> [String: [UniversityVideo]] {
        var grouped: [String: [UniversityVideo]] = [:]
        for video in videos {
            for path in video.careerPaths {
                grouped[path, default: []].append(video)
            }
        }
        return grouped
    }

    // MARK: - Matching

    /// Lightweight keyword matcher (mirrors AICareerCategorizationService's mock
    /// logic) so videos map to paths without a network round-trip.
    private func matchCareerPaths(title: String, description: String, tags: [String]) -> [String] {
        let haystack = (title + " " + description + " " + tags.joined(separator: " ")).lowercased()
        var matches: [(id: String, score: Int)] = []
        for path in CareerPath.allCareerPaths {
            let hits = path.keywords.filter { haystack.contains($0.lowercased()) }.count
            if hits > 0 { matches.append((path.id, hits)) }
        }
        return matches.sorted { $0.score > $1.score }.prefix(2).map(\.id)
    }
}
