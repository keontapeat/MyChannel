//
//  DSAComplianceService.swift
//  MyChannel
//
//  Phase 72: EU Digital Services Act + UK Online Safety Act compliance.
//  Emits the required user-facing disclosures and the server-side
//  statements of reasons (SoR) when content is moderated.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum DSARestrictionType: String, Codable {
    case removal
    case visibilityDemotion
    case accountSuspension
    case monetizationRemoved
    case ageRestriction
    case regionalBlock
}

enum DSALegalBasis: String, Codable {
    case termsOfService
    case illegalContent
    case copyright
    case privacy
    case minorProtection
    case hateSpeech
    case violentExtremism
    case fraud
    case other
}

struct StatementOfReasons: Codable, Identifiable {
    let id: String
    let userUid: String
    let contentId: String          // video/comment/stream id
    let contentKind: String        // "video" / "comment" / "stream"
    let restriction: DSARestrictionType
    let legalBasis: DSALegalBasis
    let lawCitation: String?       // e.g. "GDPR Art. 17"
    let automated: Bool            // true if ML, false if human
    let automatedSystemId: String? // e.g. "moderation-ai-v2"
    let redressInfo: String        // appeal URL + deadline text
    let createdAt: Date
    let sentAt: Date?
}

@MainActor
final class DSAComplianceService: ObservableObject {
    static let shared = DSAComplianceService()
    private init() {}

    // MARK: - Emit SoR

    /// Called whenever content gets moderated. Writes to `statementsOfReasons/{id}`
    /// and forwards to the DSA Transparency Database via the server-side function.
    func emit(_ sor: StatementOfReasons) async throws {
        guard AppConfig.Features.enableDSACompliance else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("statementsOfReasons").document(sor.id)
            .setData([
                "userUid": sor.userUid,
                "contentId": sor.contentId,
                "contentKind": sor.contentKind,
                "restriction": sor.restriction.rawValue,
                "legalBasis": sor.legalBasis.rawValue,
                "lawCitation": sor.lawCitation as Any,
                "automated": sor.automated,
                "automatedSystemId": sor.automatedSystemId as Any,
                "redressInfo": sor.redressInfo,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    // MARK: - Trusted flaggers

    struct TrustedFlag: Codable {
        let flaggerUid: String
        let organizationName: String
        let contentId: String
        let reason: String
        let createdAt: Date
    }

    func submitTrustedFlag(_ flag: TrustedFlag) async throws {
        guard AppConfig.Features.enableDSACompliance else { throw DSAError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("trustedFlags").document()
            .setData([
                "flaggerUid": flag.flaggerUid,
                "organizationName": flag.organizationName,
                "contentId": flag.contentId,
                "reason": flag.reason,
                "createdAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    // MARK: - Transparency report generation

    struct TransparencyReport: Codable {
        let year: Int
        let halfYear: Int        // 1 or 2
        let reportURL: URL
    }

    func generateHalfYearReport(year: Int, half: Int) async throws -> TransparencyReport {
        guard AppConfig.Features.enableDSACompliance else { throw DSAError.disabled }
        struct Request: Encodable { let task: String; let year: Int; let half: Int }
        struct Raw: Decodable { let url: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .legalCompliance,
            path: "/predict",
            body: Request(task: "transparency_report", year: year, half: half)
        )
        guard let urlStr = r.url, let url = URL(string: urlStr) else { throw DSAError.noURL }
        return TransparencyReport(year: year, halfYear: half, reportURL: url)
    }

    enum DSAError: LocalizedError {
        case disabled, noURL
        var errorDescription: String? {
            switch self {
            case .disabled: return "DSA compliance is disabled."
            case .noURL: return "Report not ready."
            }
        }
    }
}
