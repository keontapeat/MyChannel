import CryptoKit
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum CanonicalContentReportType: String {
    case video
    case flick
    case comment
    case liveStream = "live_stream"
    case user
    case chatMessage = "chat_message"
}

enum ContentReportSubmissionResult {
    case created
    case existing
}

enum ContentReportSubmissionError: LocalizedError {
    case invalidTarget
    case invalidReason
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidTarget: return "This content is unavailable."
        case .invalidReason: return "Select a valid report reason."
        case .unavailable: return "Reporting is temporarily unavailable."
        }
    }
}

struct ContentReportService {
    static func submit(
        type: CanonicalContentReportType,
        contentId: String,
        contentCreatorId: String,
        reporterId: String,
        reason: String,
        reasonTitle: String? = nil,
        details: String? = nil,
        videoId: String? = nil,
        streamId: String? = nil
    ) async throws -> ContentReportSubmissionResult {
        let targetId = contentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetId.isEmpty, targetId.count <= 256 else { throw ContentReportSubmissionError.invalidTarget }
        guard !normalizedReason.isEmpty, normalizedReason.count <= 200 else { throw ContentReportSubmissionError.invalidReason }
        #if canImport(FirebaseFirestore)
        let rawId = [reporterId, type.rawValue, targetId].joined(separator: "\u{1F}")
        let digest = SHA256.hash(data: Data(rawId.utf8))
        let reportId = digest.map { String(format: "%02x", $0) }.joined()
        let reportRef = Firestore.firestore().collection("content_reports").document(reportId)
        if try await reportRef.getDocument().exists { return .existing }

        var data: [String: Any] = [
            "type": type.rawValue,
            "contentId": targetId,
            "contentCreatorId": contentCreatorId,
            "reporterId": reporterId,
            "reason": normalizedReason,
            "status": "pending",
            "reviewed": false,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let reasonTitle, !reasonTitle.isEmpty { data["reasonTitle"] = String(reasonTitle.prefix(100)) }
        if let details {
            let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedDetails.isEmpty { data["details"] = String(normalizedDetails.prefix(1000)) }
        }
        if let videoId, !videoId.isEmpty { data["videoId"] = videoId }
        if let streamId, !streamId.isEmpty { data["streamId"] = streamId }
        try await reportRef.setData(data)
        return .created
        #else
        throw ContentReportSubmissionError.unavailable
        #endif
    }
}