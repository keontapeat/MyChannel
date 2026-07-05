// ⚡ PERFORMANCE: Extracted from StrikeReviewComponents.swift — independent compilation unit.
// Data models, ViewModel, and Firestore extensions compile separately.
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - User Video Model

struct UserVideo: Identifiable {
    let id: String
    let title: String
    let thumbnailURL: String?
    let views: Int
    let createdAt: Date
    let flagged: Bool
}

// MARK: - Flagged Content Model

struct FlaggedContent: Identifiable {
    let id: String
    let imageURL: String?
    let videoURL: String?
    let title: String
    let reason: String
    let flaggedAt: Date
    let reportCount: Int
    var aiAnalysisText: String? = nil
}

// MARK: - Decision Button

struct DecisionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(color.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Violation Row

struct ViolationRow: View {
    let violation: StrikeViolation
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: violation.severity == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(violation.severity == .critical ? .red : .orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(violation.type)
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text(violation.date, style: .date)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Text(violation.detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let videoTitle = violation.videoTitle {
                    Label(videoTitle, systemImage: "video.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

enum StrikeCaseStatus: String, Codable {
    case pendingReview = "pendingReview"
    case active        = "active"
    case suspended     = "suspended"
    case shadowbanned  = "shadowbanned"
    case banned        = "banned"
    case cleared       = "cleared"
    case resolved      = "resolved"

    var label: String {
        switch self {
        case .pendingReview: return "REVIEW"
        case .active:        return "ACTIVE"
        case .suspended:     return "SUSPENDED"
        case .shadowbanned:  return "SHADOWBANNED"
        case .banned:        return "BANNED"
        case .cleared:       return "CLEARED"
        case .resolved:      return "RESOLVED"
        }
    }

    var color: Color {
        switch self {
        case .pendingReview: return .orange
        case .active:        return .blue
        case .suspended:     return .purple
        case .shadowbanned:  return .indigo
        case .banned:        return .red
        case .cleared:       return .green
        case .resolved:      return .gray
        }
    }
}

enum StrikeViolationSeverity: String, Codable {
    case low, medium, high, critical
}

struct StrikeViolation: Identifiable, Codable {
    let id: String
    let type: String
    let detail: String
    let date: Date
    let videoTitle: String?
    let thumbnailURL: String?
    let severity: StrikeViolationSeverity
    let source: String     // "manual", "ai", "user_report"
}

struct StrikeCase: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let email: String
    let joinDate: Date
    let videoCount: Int
    let followerCount: Int
    var strikeCount: Int
    var status: StrikeCaseStatus
    var violations: [StrikeViolation]
    var latestViolation: String
    var lastActivity: Date
    var aiRiskScore: Int
    var aiRiskSummary: String
    var aiRecommendation: String
    var ownerNotes: String
    var ownerMessages: [String]
    var profileImageURL: String?
    var appealVideoURL: String?
    var linkedAccountsCount: Int?
    var bannedLinkedAccounts: Int?
}

enum StrikeAction: String, Codable {
    case giveChance = "giveChance"
    case issueStrike = "issueStrike"
    case suspend = "suspend"
    case shadowban = "shadowban"
    case ban = "ban"
    case clearStrikes = "clearStrikes"

    func confirmationMessage(username: String) -> String {
        switch self {
        case .giveChance:    return "Give \(username) another chance and send your message?"
        case .issueStrike:   return "Issue an official strike to \(username)?"
        case .suspend:       return "Suspend \(username)'s account temporarily?"
        case .shadowban:     return "Shadowban \(username)? They won't know they are banned, but no one will see their content."
        case .ban:           return "Permanently ban \(username)? This cannot be undone."
        case .clearStrikes:  return "Clear all strikes for \(username) and give them a fresh start?"
        }
    }
}

enum GuidelineViolationTag: String, CaseIterable, Codable {
    case hateSpeech = "hateSpeech"
    case violence = "violence"
    case nudity = "nudity"
    case harassment = "harassment"
    case copyright = "copyright"
    case spam = "spam"
    
    var label: String {
        switch self {
        case .hateSpeech: return "Hate Speech"
        case .violence: return "Violence / Harmful Content"
        case .nudity: return "Nudity / Sexual Content"
        case .harassment: return "Harassment / Cyberbullying"
        case .copyright: return "Copyright / DMCA Violation"
        case .spam: return "Spam / Scam / Deceptive Practices"
        }
    }
}

// MARK: - ViewModel

@MainActor
class StrikeViewModel: ObservableObject {
    @Published var cases: [StrikeCase] = []
    @Published var isLoading = false

    var pendingCount: Int   { cases.filter { $0.status == .pendingReview }.count }
    var oneStrikeCount: Int { cases.filter { $0.strikeCount == 1 && $0.status == .active }.count }
    var twoStrikeCount: Int { cases.filter { $0.strikeCount == 2 && $0.status == .active }.count }
    var threeStrikeCount: Int { cases.filter { $0.strikeCount >= 3 }.count }
    var bannedCount: Int    { cases.filter { $0.status == .banned }.count }

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        isLoading = true
        listener = db.collection("strikeCases")
            .order(by: "lastActivity", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                isLoading = false

                if let error { print("❌ [StrikeVM] \(error)"); return }
                guard let docs = snap?.documents else { return }

                var loaded: [StrikeCase] = []
                for doc in docs {
                    if let c = StrikeCase(from: doc) { loaded.append(c) }
                }
                cases = loaded
                print("⚖️ [StrikeVM] Loaded \(loaded.count) cases — \(pendingCount) pending")
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Apply Owner Decision

    func applyDecision(caseId: String, action: StrikeAction, ownerMessage: String?, suspendDays: Int = 7, violationTag: GuidelineViolationTag? = nil) async {
        let caseRef = db.collection("strikeCases").document(caseId)
        guard let strikeCase = cases.first(where: { $0.id == caseId }) else { return }
        let userDocRef = db.collection("users").document(strikeCase.userId)

        var caseUpdates: [String: Any] = [
            "lastActivity": Timestamp(date: Date()),
            "lastDecisionAt": Timestamp(date: Date()),
            "lastDecisionBy": "owner"
        ]
        var userUpdates: [String: Any] = [:]

        if let msg = ownerMessage, !msg.isEmpty {
            caseUpdates["ownerMessages"] = FieldValue.arrayUnion([msg])
        }

        switch action {
        case .giveChance:
            caseUpdates["status"] = StrikeCaseStatus.resolved.rawValue
            caseUpdates["resolvedAction"] = "given_chance"

        case .issueStrike:
            let newCount = strikeCase.strikeCount + 1
            caseUpdates["strikeCount"] = newCount
            caseUpdates["status"] = newCount >= 3
                ? StrikeCaseStatus.suspended.rawValue
                : StrikeCaseStatus.active.rawValue
            userUpdates["strikeCount"] = newCount
            userUpdates["lastStrikeAt"] = Timestamp(date: Date())

        case .suspend:
            let suspendInterval = Double(suspendDays) * 86400
            let suspendUntilDate = Date().addingTimeInterval(suspendInterval)
            caseUpdates["status"] = StrikeCaseStatus.suspended.rawValue
            caseUpdates["suspendedUntil"] = Timestamp(date: suspendUntilDate)
            caseUpdates["suspendDays"] = suspendDays
            userUpdates["suspended"] = true
            userUpdates["suspendedUntil"] = Timestamp(date: suspendUntilDate)

        case .shadowban:
            caseUpdates["status"] = StrikeCaseStatus.shadowbanned.rawValue
            caseUpdates["shadowbannedAt"] = Timestamp(date: Date())
            userUpdates["shadowbanned"] = true
            userUpdates["shadowbannedAt"] = Timestamp(date: Date())

        case .ban:
            caseUpdates["status"] = StrikeCaseStatus.banned.rawValue
            caseUpdates["bannedAt"] = Timestamp(date: Date())
            userUpdates["banned"] = true
            userUpdates["bannedAt"] = Timestamp(date: Date())

        case .clearStrikes:
            caseUpdates["status"] = StrikeCaseStatus.cleared.rawValue
            caseUpdates["strikeCount"] = 0
            userUpdates["strikeCount"] = 0
            userUpdates["strikesCleared"] = true
        }

        // 🔒 Atomic: the case status and the user's account-status flags must never
        // go out of sync (e.g. user shows "banned" but the case still says
        // "pendingReview" because the second write failed after the first
        // succeeded). Idempotency guard: re-running the same decision on an
        // already-applied case is a no-op status flip, not a double-charge, so a
        // batch (rather than a full transaction) is sufficient here.
        let batch = db.batch()
        batch.updateData(caseUpdates, forDocument: caseRef)
        if !userUpdates.isEmpty {
            batch.updateData(userUpdates, forDocument: userDocRef)
        }

        do {
            try await batch.commit()

            // Side effects (notification, audit log) are best-effort and don't need
            // to be atomic with the status change — a missed notification shouldn't
            // block the moderation decision from taking effect.
            if let msg = ownerMessage, !msg.isEmpty {
                // Also write to the user's real notifications inbox (NotificationsInboxService
                // reads the "notifications" collection, not "userNotifications" — writing to
                // the wrong collection meant owner messages were silently never seen in-app).
                await notifyUser(userId: strikeCase.userId, title: "Message from MyChannel", body: msg)
            }

            switch action {
            case .giveChance:
                await notifyUser(userId: strikeCase.userId, title: "⚠️ Account Warning",
                                 body: ownerMessage ?? "You have been given another chance. Please follow our community guidelines.")
            case .issueStrike:
                let newCount = strikeCase.strikeCount + 1
                await notifyUser(userId: strikeCase.userId,
                                 title: "🔴 Strike \(newCount) of 3 — \(strikeCase.username)",
                                 body: ownerMessage ?? "You have received strike \(newCount)/3. At 3 strikes your account may be removed.")
            case .suspend:
                await notifyUser(userId: strikeCase.userId, title: "🚫 Account Suspended",
                                 body: ownerMessage ?? "Your account has been suspended for \(suspendDays) days due to repeated violations.")
            case .shadowban:
                break // Notice: We don't notify the user of a shadowban, that's the whole point!
            case .ban:
                await notifyUser(userId: strikeCase.userId, title: "❌ Account Removed",
                                 body: ownerMessage ?? "Your account has been permanently removed from MyChannel.")
            case .clearStrikes:
                await notifyUser(userId: strikeCase.userId, title: "✅ Fresh Start",
                                 body: ownerMessage ?? "Your strikes have been cleared. Welcome back — please follow our community guidelines.")
            }

            let actionReason = ownerMessage ?? "No explanation provided"
            await logModeratorAction(userId: strikeCase.userId, username: strikeCase.username, action: action, tag: violationTag, reason: actionReason)

            // Update local state
            if let idx = cases.firstIndex(where: { $0.id == caseId }) {
                switch action {
                case .giveChance:    cases[idx].status = .resolved
                case .issueStrike:
                    cases[idx].strikeCount += 1
                    cases[idx].status = cases[idx].strikeCount >= 3 ? .suspended : .active
                case .suspend:       cases[idx].status = .suspended
                case .shadowban:     cases[idx].status = .shadowbanned
                case .ban:           cases[idx].status = .banned
                case .clearStrikes:  cases[idx].strikeCount = 0; cases[idx].status = .cleared
                }
            }
            print("✅ [StrikeVM] Decision applied: \(action) for \(strikeCase.username)")
        } catch {
            print("❌ [StrikeVM] Failed to apply decision: \(error)")
        }
    }

    func logModeratorAction(userId: String, username: String, action: StrikeAction, tag: GuidelineViolationTag?, reason: String) async {
        let moderatorId = Auth.auth().currentUser?.uid ?? "unknown_moderator"
        let logData: [String: Any] = [
            "moderatorId": moderatorId,
            "userId": userId,
            "username": username,
            "actionType": action.rawValue,
            "violationTag": tag?.rawValue ?? "",
            "ownerMessage": reason,
            "timestamp": Timestamp(date: Date())
        ]
        do {
            try await db.collection("moderatorActionsLog").addDocument(data: logData)
            print("📝 [StrikeVM] Moderator action logged to Firestore successfully")
        } catch {
            print("❌ [StrikeVM] Failed to write audit log: \(error)")
        }
    }

    // NOTE: Auto-creation/escalation of strikeCases from AI detections is handled
    // directly by PlatformMonitorService.autoQueueStrikeCase(...) — that's the one
    // path actually wired up. (A duplicate `issueAutoStrike` used to live here but
    // nothing called it; removed to avoid two divergent implementations of the
    // same escalation logic.)

    // MARK: - Notify User

    /// Writes into the "notifications" collection — the one NotificationsInboxService
    /// actually queries (userId/isRead/createdAt) — so strike decisions are visible in
    /// the user's real in-app notification inbox, not a collection nothing reads.
    private func notifyUser(userId: String, title: String, body: String) async {
        let data: [String: Any] = [
            "userId": userId,
            "type": "system",
            "title": title,
            "body": body,
            "createdAt": Timestamp(date: Date()),
            "isRead": false
        ]
        try? await db.collection("notifications").addDocument(data: data)
    }
}


// MARK: - StrikeCase Firestore Init

extension StrikeCase {
    init?(from doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let statusRaw = data["status"] as? String,
              let status = StrikeCaseStatus(rawValue: statusRaw) else { return nil }

        id            = doc.documentID
        self.userId   = userId
        self.username = username
        email         = data["email"] as? String ?? ""
        joinDate      = (data["joinDate"] as? Timestamp)?.dateValue() ?? Date()
        videoCount    = data["videoCount"] as? Int ?? 0
        followerCount = data["followerCount"] as? Int ?? 0
        strikeCount   = data["strikeCount"] as? Int ?? 0
        self.status   = status
        latestViolation = data["latestViolation"] as? String ?? "Unknown violation"
        lastActivity  = (data["lastActivity"] as? Timestamp)?.dateValue() ?? Date()
        aiRiskScore   = data["aiRiskScore"] as? Int ?? 0
        aiRiskSummary = data["aiRiskSummary"] as? String ?? ""
        aiRecommendation = data["aiRecommendation"] as? String ?? "Review Required"
        ownerNotes    = data["ownerNotes"] as? String ?? ""
        ownerMessages = data["ownerMessages"] as? [String] ?? []
        profileImageURL = data["profileImageURL"] as? String ?? data["photoURL"] as? String
        appealVideoURL = data["appealVideoURL"] as? String
        linkedAccountsCount = data["linkedAccountsCount"] as? Int
        bannedLinkedAccounts = data["bannedLinkedAccounts"] as? Int

        // Parse violations array
        let rawViolations = data["violations"] as? [[String: Any]] ?? []
        violations = rawViolations.compactMap { v -> StrikeViolation? in
            guard let type = v["type"] as? String,
                  let detail = v["detail"] as? String else { return nil }
            let sev = StrikeViolationSeverity(rawValue: v["severity"] as? String ?? "high") ?? .high
            return StrikeViolation(
                id: v["id"] as? String ?? UUID().uuidString,
                type: type,
                detail: detail,
                date: (v["date"] as? Timestamp)?.dateValue() ?? Date(),
                videoTitle: v["videoTitle"] as? String,
                thumbnailURL: v["thumbnailURL"] as? String,
                severity: sev,
                source: v["source"] as? String ?? "ai"
            )
        }
    }
}

// MARK: - Violation Firestore Serialization

extension StrikeViolation {
    var firestoreData: [String: Any] {
        var d: [String: Any] = [
            "id": id,
            "type": type,
            "detail": detail,
            "date": Timestamp(date: date),
            "severity": severity.rawValue,
            "source": source
        ]
        if let t = videoTitle { d["videoTitle"] = t }
        if let u = thumbnailURL { d["thumbnailURL"] = u }
        return d
    }
}
