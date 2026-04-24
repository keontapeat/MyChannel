//
//  LEPortalService.swift
//  MyChannel
//
//  Phase 75: Law Enforcement Portal (ops-side).
//  iOS-side surface is minimal — creators/users get notifications when
//  their account is subject to a preservation request or legal process.
//  The full intake workflow runs on `le-portal.mychannel.live` with
//  two-person approval.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum LERequestType: String, Codable {
    case preservation            // hold for 90 days
    case production              // provide records
    case emergencyDisclosure     // ECPA 702(c)(4)
    case wiretap
    case nationalSecurityLetter
}

struct LENotice: Codable, Identifiable {
    let id: String
    let userUid: String
    let requestType: LERequestType
    let jurisdiction: String     // e.g. "US-FBI"
    let openedAt: Date
    let gagOrderActive: Bool     // if true, suppress user-facing notice
    let publicReferenceId: String?  // redacted case ID
}

@MainActor
final class LEPortalService: ObservableObject {
    static let shared = LEPortalService()
    private init() {}

    /// Returns notices for the current user where no gag order is in effect.
    /// Gag-ordered notices are still stored; they just don't surface in-app.
    func publicNotices(userUid: String) async throws -> [LENotice] {
        guard AppConfig.Features.enableLEPortal else { return [] }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("leNotices")
            .whereField("userUid", isEqualTo: userUid)
            .whereField("gagOrderActive", isEqualTo: false)
            .order(by: "openedAt", descending: true)
            .getDocuments()

        return snap.documents.compactMap { doc -> LENotice? in
            let d = doc.data()
            guard
                let typeRaw = d["requestType"] as? String,
                let type = LERequestType(rawValue: typeRaw)
            else { return nil }
            return LENotice(
                id: doc.documentID,
                userUid: userUid,
                requestType: type,
                jurisdiction: d["jurisdiction"] as? String ?? "",
                openedAt: (d["openedAt"] as? Timestamp)?.dateValue() ?? Date(),
                gagOrderActive: d["gagOrderActive"] as? Bool ?? false,
                publicReferenceId: d["publicReferenceId"] as? String
            )
        }
        #else
        return []
        #endif
    }

    /// Public-facing LE portal URL (opened externally via SFSafariViewController).
    static let portalURL = URL(string: "https://transparency.mychannel.live/law-enforcement")!

    /// Creator-facing "Learn more about what was requested" doc. Suppressed
    /// when a notice is under gag.
    static func learnMoreURL(for notice: LENotice) -> URL {
        URL(string: "https://transparency.mychannel.live/notices/\(notice.id)")!
    }
}
