//
//  CreatorAcademyService.swift
//  MyChannel
//
//  Phase 170: Creator Academy & Certification.
//  Interactive courses, skill badges, monetization milestones.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct AcademyCourse: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let category: String
    let lessonsCount: Int
    let durationMinutes: Int
    let difficulty: String
    let badgeId: String?
}

struct CourseProgress: Codable, Identifiable {
    let id: String
    let uid: String
    let courseId: String
    let completedLessons: Int
    let totalLessons: Int
    let completed: Bool
    let lastAccessedAt: Date
}

struct SkillBadge: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let description: String
    let earnedAt: Date?
}

struct MonetizationMilestone: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let threshold: Int
    let currentProgress: Int
    let unlocked: Bool
}

// MARK: - Service

@MainActor
final class CreatorAcademyService: ObservableObject {
    static let shared = CreatorAcademyService()
    private init() {}

    @Published private(set) var courses: [AcademyCourse] = []
    @Published private(set) var progress: [CourseProgress] = []
    @Published private(set) var badges: [SkillBadge] = []
    @Published private(set) var milestones: [MonetizationMilestone] = []

    func loadCourses() async throws {
        guard AppConfig.Features.enableCreatorAcademy else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("academy_courses").order(by: "title").getDocuments()
        courses = snap.documents.compactMap { doc in
            let d = doc.data()
            return AcademyCourse(
                id: doc.documentID, title: d["title"] as? String ?? "",
                description: d["description"] as? String ?? "",
                category: d["category"] as? String ?? "",
                lessonsCount: d["lessonsCount"] as? Int ?? 0,
                durationMinutes: d["durationMinutes"] as? Int ?? 0,
                difficulty: d["difficulty"] as? String ?? "beginner",
                badgeId: d["badgeId"] as? String
            )
        }
        #endif
    }

    func loadProgress(uid: String) async throws {
        guard AppConfig.Features.enableCreatorAcademy else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("academy_progress").whereField("uid", isEqualTo: uid).getDocuments()
        progress = snap.documents.compactMap { doc in
            let d = doc.data()
            return CourseProgress(
                id: doc.documentID, uid: d["uid"] as? String ?? "",
                courseId: d["courseId"] as? String ?? "",
                completedLessons: d["completedLessons"] as? Int ?? 0,
                totalLessons: d["totalLessons"] as? Int ?? 0,
                completed: d["completed"] as? Bool ?? false,
                lastAccessedAt: (d["lastAccessedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #endif
    }

    func completeLesson(uid: String, courseId: String) async throws {
        guard AppConfig.Features.enableCreatorAcademy else { return }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("academy_progress").document("\(uid)_\(courseId)")
        try await ref.setData([
            "uid": uid, "courseId": courseId,
            "completedLessons": FieldValue.increment(Int64(1)),
            "lastAccessedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }

    func loadBadges(uid: String) async throws {
        guard AppConfig.Features.enableCreatorAcademy else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("skill_badges").whereField("uid", isEqualTo: uid).getDocuments()
        badges = snap.documents.compactMap { doc in
            let d = doc.data()
            return SkillBadge(id: doc.documentID, name: d["name"] as? String ?? "",
                            iconName: d["iconName"] as? String ?? "star",
                            description: d["description"] as? String ?? "",
                            earnedAt: (d["earnedAt"] as? Timestamp)?.dateValue())
        }
        #endif
    }
}
