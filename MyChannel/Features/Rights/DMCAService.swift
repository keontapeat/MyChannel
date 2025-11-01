import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct DMCARequest: Identifiable, Codable {
    let id: String
    let claimantName: String
    let claimantEmail: String
    let claimantOrganization: String?
    let copyrightedWork: String
    let infringingURL: String
    let videoId: String
    let description: String
    let swornStatement: Bool
    let goodFaithBelief: Bool
    let status: DMCAStatus
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let counterNoticeDeadline: Date?
    let evidence: [Evidence]
    
    struct Evidence: Identifiable, Codable {
        let id = UUID().uuidString
        let type: EvidenceType
        let url: String
        let description: String
        
        enum EvidenceType: String, Codable {
            case document, video, audio, image, link
        }
    }
    
    enum DMCAStatus: String, Codable, CaseIterable {
        case submitted, underReview, accepted, rejected, counterNoticed, resolved
        
        var displayName: String {
            switch self {
            case .submitted: return "Submitted"
            case .underReview: return "Under Review"
            case .accepted: return "Accepted"
            case .rejected: return "Rejected"
            case .counterNoticed: return "Counter Notice Filed"
            case .resolved: return "Resolved"
            }
        }
        
        var color: Color {
            switch self {
            case .submitted: return .blue
            case .underReview: return .orange
            case .accepted: return .red
            case .rejected: return .gray
            case .counterNoticed: return .purple
            case .resolved: return .green
            }
        }
    }
}

struct CounterNotice: Identifiable, Codable {
    let id: String
    let dmcaRequestId: String
    let creatorName: String
    let creatorEmail: String
    let creatorAddress: String
    let statement: String
    let swornStatement: Bool
    let consent: Bool
    let signature: String
    let submittedAt: Date
    let status: CounterNoticeStatus
    
    enum CounterNoticeStatus: String, Codable {
        case submitted, underReview, accepted, rejected
    }
}

@MainActor
final class DMCAService: ObservableObject {
    static let shared = DMCAService()
    private init() {}
    
    @Published var requests: [DMCARequest] = []
    @Published var counterNotices: [CounterNotice] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var requestsListener: ListenerRegistration?
    private var counterNoticesListener: ListenerRegistration?
    #endif
    
    func submitDMCARequest(
        claimantName: String,
        claimantEmail: String,
        claimantOrganization: String?,
        copyrightedWork: String,
        infringingURL: String,
        videoId: String,
        description: String,
        evidence: [DMCARequest.Evidence]
    ) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("dmca_requests").document()
            try await ref.setData([
                "claimantName": claimantName,
                "claimantEmail": claimantEmail,
                "claimantOrganization": claimantOrganization as Any,
                "copyrightedWork": copyrightedWork,
                "infringingURL": infringingURL,
                "videoId": videoId,
                "description": description,
                "swornStatement": true,
                "goodFaithBelief": true,
                "status": DMCARequest.DMCAStatus.submitted.rawValue,
                "submittedAt": FieldValue.serverTimestamp(),
                "evidence": evidence.map { [
                    "type": $0.type.rawValue,
                    "url": $0.url,
                    "description": $0.description
                ]},
                "counterNoticeDeadline": Timestamp(date: Date().addingTimeInterval(14 * 24 * 3600)) // 14 days
            ])
            
            // Automatically restrict content pending review
            await restrictContent(videoId: videoId, reason: "DMCA claim pending review")
            
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func submitCounterNotice(
        dmcaRequestId: String,
        creatorName: String,
        creatorEmail: String,
        creatorAddress: String,
        statement: String,
        signature: String
    ) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("counter_notices").document()
            try await ref.setData([
                "dmcaRequestId": dmcaRequestId,
                "creatorName": creatorName,
                "creatorEmail": creatorEmail,
                "creatorAddress": creatorAddress,
                "statement": statement,
                "swornStatement": true,
                "consent": true,
                "signature": signature,
                "submittedAt": FieldValue.serverTimestamp(),
                "status": CounterNotice.CounterNoticeStatus.submitted.rawValue
            ])
            
            // Update DMCA request status
            try await db.collection("dmca_requests").document(dmcaRequestId).setData([
                "status": DMCARequest.DMCAStatus.counterNoticed.rawValue
            ], merge: true)
            
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func reviewDMCARequest(requestId: String, decision: DMCARequest.DMCAStatus, reviewerId: String, notes: String?) async {
        #if canImport(FirebaseFirestore)
        do {
            var data: [String: Any] = [
                "status": decision.rawValue,
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": reviewerId
            ]
            if let notes = notes { data["reviewNotes"] = notes }
            
            try await db.collection("dmca_requests").document(requestId).setData(data, merge: true)
            
            // Handle content based on decision
            if let request = requests.first(where: { $0.id == requestId }) {
                switch decision {
                case .accepted:
                    await takedownContent(videoId: request.videoId, reason: "DMCA takedown")
                case .rejected:
                    await restoreContent(videoId: request.videoId)
                default:
                    break
                }
            }
        } catch { }
        #endif
    }
    
    func listenToRequests() {
        #if canImport(FirebaseFirestore)
        requestsListener?.remove()
        requestsListener = db.collection("dmca_requests")
            .order(by: "submittedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.requests = docs.compactMap { doc in
                    let d = doc.data()
                    let evidenceArray = d["evidence"] as? [[String: Any]] ?? []
                    let evidence = evidenceArray.compactMap { evidenceDict -> DMCARequest.Evidence? in
                        guard let type = evidenceDict["type"] as? String,
                              let url = evidenceDict["url"] as? String,
                              let description = evidenceDict["description"] as? String else { return nil }
                        return DMCARequest.Evidence(
                            type: DMCARequest.Evidence.EvidenceType(rawValue: type) ?? .document,
                            url: url,
                            description: description
                        )
                    }
                    
                    return DMCARequest(
                        id: doc.documentID,
                        claimantName: d["claimantName"] as? String ?? "",
                        claimantEmail: d["claimantEmail"] as? String ?? "",
                        claimantOrganization: d["claimantOrganization"] as? String,
                        copyrightedWork: d["copyrightedWork"] as? String ?? "",
                        infringingURL: d["infringingURL"] as? String ?? "",
                        videoId: d["videoId"] as? String ?? "",
                        description: d["description"] as? String ?? "",
                        swornStatement: d["swornStatement"] as? Bool ?? false,
                        goodFaithBelief: d["goodFaithBelief"] as? Bool ?? false,
                        status: DMCARequest.DMCAStatus(rawValue: d["status"] as? String ?? "submitted") ?? .submitted,
                        submittedAt: (d["submittedAt"] as? Timestamp)?.dateValue() ?? Date(),
                        reviewedAt: (d["reviewedAt"] as? Timestamp)?.dateValue(),
                        reviewedBy: d["reviewedBy"] as? String,
                        counterNoticeDeadline: (d["counterNoticeDeadline"] as? Timestamp)?.dateValue(),
                        evidence: evidence
                    )
                }
            }
        #endif
    }
    
    private func restrictContent(videoId: String, reason: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("videos").document(videoId).setData([
                "visibility": "restricted",
                "restrictionReason": reason,
                "restrictedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }
    
    private func takedownContent(videoId: String, reason: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("videos").document(videoId).setData([
                "visibility": "removed",
                "removalReason": reason,
                "removedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }
    
    private func restoreContent(videoId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("videos").document(videoId).setData([
                "visibility": "public",
                "restoredAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }
    
    func stopListening() {
        #if canImport(FirebaseFirestore)
        requestsListener?.remove()
        counterNoticesListener?.remove()
        #endif
    }
}
