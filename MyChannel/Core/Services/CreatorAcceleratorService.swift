//
//  CreatorAcceleratorService.swift
//  MyChannel
//
//  Phase 97: Creator Accelerator Program.
//  Cohort-based grants, hardware perks, and mentorship for emerging creators.
//  Applications and progress tracked via Firestore `accelerator/` collection.
//  ROI analytics fed back into BigQuery through `creator-fund-allocator`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum AcceleratorCohort: String, Codable {
    case cohort1 = "cohort_1"
    case cohort2 = "cohort_2"
    case cohort3 = "cohort_3"
    // Extend as new cohorts launch.
}

enum ApplicationStatus: String, Codable {
    case draft, submitted, underReview, accepted, rejected, graduated
}

struct AcceleratorApplication: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let cohort: AcceleratorCohort
    let channelURL: String
    let pitch: String                // 500-char elevator pitch
    let category: String             // niche: "gaming", "beauty", "tech", ...
    let monthlyViewsRange: String    // e.g. "10k-50k"
    let subscriberCount: Int
    let hardwareRequested: Bool
    let mentorshipRequested: Bool
    let grantAmountRequestedUSD: Decimal
    let status: ApplicationStatus
    let submittedAt: Date?
    let decidedAt: Date?
    let notes: String?
}

struct AcceleratorMilestone: Codable, Identifiable, Equatable {
    let id: String
    let applicationId: String
    let title: String
    let description: String
    let targetDate: Date
    let completedAt: Date?
    let kpiTarget: Double    // e.g. 50000 (views)
    let kpiActual: Double?
    let kpiLabel: String     // e.g. "monthly_views"
}

@MainActor
final class CreatorAcceleratorService: ObservableObject {
    static let shared = CreatorAcceleratorService()
    private init() {}

    @Published private(set) var myApplication: AcceleratorApplication?

    // MARK: - Apply

    func submit(application: AcceleratorApplication) async throws {
        guard AppConfig.Features.enableCreatorAccelerator else { throw AccelError.disabled }
        #if canImport(FirebaseFirestore)
        var data: [String: Any] = [
            "creatorUid": application.creatorUid,
            "cohort": application.cohort.rawValue,
            "channelURL": application.channelURL,
            "pitch": application.pitch,
            "category": application.category,
            "monthlyViewsRange": application.monthlyViewsRange,
            "subscriberCount": application.subscriberCount,
            "hardwareRequested": application.hardwareRequested,
            "mentorshipRequested": application.mentorshipRequested,
            "grantAmountRequestedUSD": (application.grantAmountRequestedUSD as NSDecimalNumber).doubleValue,
            "status": ApplicationStatus.submitted.rawValue,
            "submittedAt": FieldValue.serverTimestamp()
        ]
        if let notes = application.notes { data["notes"] = notes }

        try await Firestore.firestore()
            .collection("accelerator").document(application.id)
            .setData(data)

        myApplication = application
        #endif
    }

    func loadMyApplication(creatorUid: String) async throws {
        guard AppConfig.Features.enableCreatorAccelerator else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("accelerator")
            .whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "submittedAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first else { return }
        let d = doc.data()
        guard
            let cohortRaw = d["cohort"] as? String,
            let cohort = AcceleratorCohort(rawValue: cohortRaw),
            let statusRaw = d["status"] as? String,
            let status = ApplicationStatus(rawValue: statusRaw)
        else { return }
        myApplication = AcceleratorApplication(
            id: doc.documentID,
            creatorUid: creatorUid,
            cohort: cohort,
            channelURL: d["channelURL"] as? String ?? "",
            pitch: d["pitch"] as? String ?? "",
            category: d["category"] as? String ?? "",
            monthlyViewsRange: d["monthlyViewsRange"] as? String ?? "",
            subscriberCount: d["subscriberCount"] as? Int ?? 0,
            hardwareRequested: d["hardwareRequested"] as? Bool ?? false,
            mentorshipRequested: d["mentorshipRequested"] as? Bool ?? false,
            grantAmountRequestedUSD: Decimal(d["grantAmountRequestedUSD"] as? Double ?? 0),
            status: status,
            submittedAt: (d["submittedAt"] as? Timestamp)?.dateValue(),
            decidedAt: (d["decidedAt"] as? Timestamp)?.dateValue(),
            notes: d["notes"] as? String
        )
        #endif
    }

    // MARK: - Milestones

    func milestones(for applicationId: String) async throws -> [AcceleratorMilestone] {
        guard AppConfig.Features.enableCreatorAccelerator else { return [] }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("accelerator").document(applicationId)
            .collection("milestones")
            .order(by: "targetDate")
            .getDocuments()
        return snap.documents.compactMap { doc -> AcceleratorMilestone? in
            let d = doc.data()
            guard let title = d["title"] as? String else { return nil }
            return AcceleratorMilestone(
                id: doc.documentID,
                applicationId: applicationId,
                title: title,
                description: d["description"] as? String ?? "",
                targetDate: (d["targetDate"] as? Timestamp)?.dateValue() ?? Date(),
                completedAt: (d["completedAt"] as? Timestamp)?.dateValue(),
                kpiTarget: d["kpiTarget"] as? Double ?? 0,
                kpiActual: d["kpiActual"] as? Double,
                kpiLabel: d["kpiLabel"] as? String ?? "views"
            )
        }
        #else
        return []
        #endif
    }

    enum AccelError: LocalizedError {
        case disabled
        var errorDescription: String? { "Creator Accelerator is not enabled." }
    }
}
