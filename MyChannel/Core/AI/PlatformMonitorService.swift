//
//  PlatformMonitorService.swift
//  MyChannel
//
//  Background platform monitor — runs 24/7, scans every 60 seconds.
//  Detects fraud, flags bad content, tracks user events, writes to Firestore.
//  Feeds the OwnerCommandCenter in real time.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Platform Monitor Service

@MainActor
final class PlatformMonitorService: ObservableObject {
    static let shared = PlatformMonitorService()

    @Published var isRunning = false
    @Published var lastScanTime: Date?
    @Published var totalScansToday: Int = 0
    @Published var fraudCaught: Int = 0
    @Published var contentFlagged: Int = 0
    @Published var eventsLogged: Int = 0

    private var db = Firestore.firestore()
    private var monitorTimer: Timer?
    private var deepScanTimer: Timer?
    private let scanInterval: TimeInterval = 60        // Light scan every 60s
    private let deepScanInterval: TimeInterval = 3600  // Deep scan every hour

    private init() {}

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        print("🛡️ [PlatformMonitor] Started — scanning every \(Int(scanInterval))s")

        // Run immediately
        Task { await runFullScan() }

        // Light scan every 60 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runLightScan() }
        }

        // Deep scan every hour
        deepScanTimer = Timer.scheduledTimer(withTimeInterval: deepScanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runFullScan() }
        }
    }

    func stop() {
        monitorTimer?.invalidate()
        deepScanTimer?.invalidate()
        monitorTimer = nil
        deepScanTimer = nil
        isRunning = false
        print("🛑 [PlatformMonitor] Stopped")
    }

    // MARK: - Light Scan (every 60s)

    func runLightScan() async {
        totalScansToday += 1
        lastScanTime = Date()

        // Run all light checks in parallel
        async let fraudCheck: Void = scanForFraudSignals()
        async let contentCheck: Void = scanNewUploadsForViolations()
        async let userCheck: Void = trackUserActivitySpikes()
        _ = await (fraudCheck, contentCheck, userCheck)
    }

    // MARK: - Full Scan (every hour)

    func runFullScan() async {
        print("🔍 [PlatformMonitor] Running full platform scan...")
        await runLightScan()
        await scanForBotAccounts()
        await scanForPaymentAnomalies()
        await scanForViewManipulation()
        await updatePlatformHealthScore()
        print("✅ [PlatformMonitor] Full scan complete — \(fraudCaught) fraud, \(contentFlagged) content flags")
    }

    // MARK: - Fraud Detection

    private func scanForFraudSignals() async {
        // Check recent ad clicks for suspicious patterns
        db.collection("adClicks")
            .order(by: "timestamp", descending: true)
            .limit(to: 200)
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                var suspiciousClusters: [String: Int] = [:]
                for doc in docs {
                    let data = doc.data()
                    let ip = data["ipAddress"] as? String ?? "unknown"
                    suspiciousClusters[ip, default: 0] += 1
                }

                // Flag IPs with >20 clicks in the last 200
                for (ip, count) in suspiciousClusters where count > 20 {
                    Task { @MainActor in
                        await self.writeFraudAlert(
                            type: "Click Fraud",
                            description: "IP \(ip) made \(count) ad clicks — possible click farm",
                            amount: "$\(count * 3)",
                            userId: ip
                        )
                    }
                }
            }

        // Check for fake view inflation
        db.collection("videoViews")
            .whereField("timestamp", isGreaterThan: Timestamp(date: Date().addingTimeInterval(-300)))
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                var viewsByVideo: [String: Int] = [:]
                var viewsByUser: [String: Int] = [:]
                for doc in docs {
                    let data = doc.data()
                    let vid = data["videoId"] as? String ?? ""
                    let uid = data["userId"] as? String ?? ""
                    viewsByVideo[vid, default: 0] += 1
                    viewsByUser[uid, default: 0] += 1
                }

                // Flag users watching 10+ different videos in 5 minutes
                for (uid, count) in viewsByUser where count > 10 {
                    Task { @MainActor in
                        await self.writeFraudAlert(
                            type: "View Manipulation",
                            description: "User \(uid.prefix(12))... watched \(count) videos in 5 min — bot suspected",
                            amount: "$\(count * 2)",
                            userId: uid
                        )
                    }
                }
            }
    }

    private func scanForBotAccounts() async {
        // Look for accounts created in last 24h with suspicious activity
        let yesterday = Date().addingTimeInterval(-86400)
        db.collection("users")
            .whereField("createdAt", isGreaterThan: Timestamp(date: yesterday))
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                for doc in docs {
                    let data = doc.data()
                    let viewCount = data["viewCount"] as? Int ?? 0
                    let followCount = data["followCount"] as? Int ?? 0
                    let uid = doc.documentID

                    // Newly created accounts with suspiciously high activity
                    if viewCount > 500 || followCount > 100 {
                        Task { @MainActor in
                            await self.writeFraudAlert(
                                type: "Bot Account",
                                description: "New account (uid: \(uid.prefix(12))...) — \(viewCount) views, \(followCount) follows in <24h",
                                amount: "$0",
                                userId: uid
                            )
                        }
                    }
                }
            }
    }

    private func scanForPaymentAnomalies() async {
        // Check for suspicious payment patterns
        let oneHourAgo = Date().addingTimeInterval(-3600)
        db.collection("payments")
            .whereField("timestamp", isGreaterThan: Timestamp(date: oneHourAgo))
            .whereField("status", isEqualTo: "failed")
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                var failedByUser: [String: Int] = [:]
                for doc in docs {
                    let uid = doc.data()["userId"] as? String ?? "unknown"
                    failedByUser[uid, default: 0] += 1
                }

                for (uid, count) in failedByUser where count >= 3 {
                    Task { @MainActor in
                        await self.writeFraudAlert(
                            type: "Payment Fraud",
                            description: "User \(uid.prefix(12))... had \(count) failed payments in 1hr — possible card testing",
                            amount: "$0",
                            userId: uid
                        )
                    }
                }
            }
    }

    private func scanForViewManipulation() async {
        // Check for videos with suspiciously fast view spikes
        db.collection("videos")
            .order(by: "viewCount", descending: true)
            .limit(to: 20)
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                for doc in docs {
                    let data = doc.data()
                    let views = data["viewCount"] as? Int ?? 0
                    let createdTs = data["createdAt"] as? Timestamp
                    let created = createdTs?.dateValue() ?? Date()
                    let ageHours = max(1, Int(Date().timeIntervalSince(created) / 3600))
                    let viewsPerHour = views / ageHours

                    // More than 10K views/hour on a new video is suspicious
                    if viewsPerHour > 10_000 && ageHours < 24 {
                        Task { @MainActor in
                            let title = data["title"] as? String ?? "Unknown Video"
                            let uid = data["userId"] as? String ?? "unknown"
                            await self.writeFraudAlert(
                                type: "View Inflation",
                                description: "'\(title)' — \(viewsPerHour.formatted())+ views/hr in first \(ageHours)hrs — suspected manipulation",
                                amount: "$\(viewsPerHour / 100)",
                                userId: uid
                            )
                        }
                    }
                }
            }
    }

    // MARK: - Content Moderation

    private func scanNewUploadsForViolations() async {
        // Scan videos uploaded in last 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        db.collection("videos")
            .whereField("createdAt", isGreaterThan: Timestamp(date: fiveMinutesAgo))
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                for doc in docs {
                    let data = doc.data()
                    let title = (data["title"] as? String ?? "").lowercased()
                    let description = (data["description"] as? String ?? "").lowercased()
                    let tags = (data["tags"] as? [String] ?? []).joined(separator: " ").lowercased()
                    let combined = title + " " + description + " " + tags
                    let uid = data["userId"] as? String ?? "unknown"
                    let displayTitle = data["title"] as? String ?? "Untitled"
                    let creatorName = data["channelName"] as? String ?? "Unknown Creator"
                    let thumbnailURL = data["thumbnailURL"] as? String ?? data["thumbnail"] as? String

                    // Check for violation keywords
                    if let violation = self.detectViolation(in: combined) {
                        Task { @MainActor in
                            await self.writeContentFlag(
                                videoId: doc.documentID,
                                videoTitle: displayTitle,
                                creatorName: creatorName,
                                creatorId: uid,
                                violationType: violation.type,
                                confidence: violation.confidence,
                                thumbnailURL: thumbnailURL
                            )
                        }
                    }
                }
            }

        // Also scan recent comments
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        db.collection("comments")
            .whereField("createdAt", isGreaterThan: Timestamp(date: tenMinutesAgo))
            .limit(to: 100)
            .getDocuments { [weak self] snap, _ in
                guard let self, let docs = snap?.documents else { return }

                for doc in docs {
                    let data = doc.data()
                    let text = (data["text"] as? String ?? "").lowercased()
                    let uid = data["userId"] as? String ?? "unknown"

                    if let violation = self.detectViolation(in: text) {
                        // Auto-remove if high confidence
                        if violation.confidence >= 95 {
                            doc.reference.updateData(["hidden": true, "autoModerated": true, "moderationReason": violation.type])
                        } else {
                            Task { @MainActor in
                                await self.writeContentFlag(
                                    videoId: data["videoId"] as? String ?? "",
                                    videoTitle: "Comment by user",
                                    creatorName: "Comment",
                                    creatorId: uid,
                                    violationType: "Comment: \(violation.type)",
                                    confidence: violation.confidence
                                )
                            }
                        }
                    }
                }
            }
    }

    // MARK: - User Activity

    private func trackUserActivitySpikes() async {
        // Track concurrent active users and log to Firestore
        db.collection("activeSessions")
            .whereField("lastActive", isGreaterThan: Timestamp(date: Date().addingTimeInterval(-120)))
            .getDocuments { [weak self] snap, _ in
                guard let self else { return }
                let count = snap?.documents.count ?? 0

                // Log activity snapshot every scan
                let data: [String: Any] = [
                    "activeUsers": count,
                    "timestamp": Timestamp(date: Date()),
                    "source": "PlatformMonitor"
                ]
                self.db.collection("platformMetrics").addDocument(data: data)

                Task { @MainActor in self.eventsLogged += 1 }
            }
    }

    // MARK: - Platform Health Score

    private func updatePlatformHealthScore() async {
        // Calculate and write platform health to Firestore
        let fraudRate = min(1.0, Double(fraudCaught) / max(1.0, Double(totalScansToday * 10)))
        let contentViolationRate = min(1.0, Double(contentFlagged) / max(1.0, Double(totalScansToday * 5)))
        let health = max(0, 100 - (fraudRate * 30) - (contentViolationRate * 20))

        let data: [String: Any] = [
            "healthScore": health,
            "fraudAlerts": fraudCaught,
            "contentFlags": contentFlagged,
            "scansToday": totalScansToday,
            "timestamp": Timestamp(date: Date()),
            "updatedBy": "PlatformMonitorService"
        ]
        try? await db.collection("platformHealth").document("current").setData(data, merge: true)
        print("📊 [PlatformMonitor] Health: \(Int(health))% | Fraud: \(fraudCaught) | Content: \(contentFlagged)")
    }

    // MARK: - Firestore Writers

    private func writeFraudAlert(type: String, description: String, amount: String, userId: String) async {
        // Check if a similar alert already exists (dedup)
        let existing = try? await db.collection("fraudAlerts")
            .whereField("type", isEqualTo: type)
            .whereField("userId", isEqualTo: userId)
            .whereField("reviewed", isEqualTo: false)
            .getDocuments()

        guard existing?.documents.isEmpty != false else { return }

        let data: [String: Any] = [
            "type": type,
            "description": description,
            "amount": amount,
            "userId": userId,
            "timestamp": Timestamp(date: Date()),
            "reviewed": false,
            "source": "PlatformMonitorService",
            "severity": amount.contains("0") ? "low" : "high"
        ]
        do {
            try await db.collection("fraudAlerts").addDocument(data: data)
            fraudCaught += 1
            print("🚨 [Fraud] \(type) — \(description.prefix(60))")
        } catch {
            print("❌ [PlatformMonitor] Failed to write fraud alert: \(error)")
        }
    }

    private func writeContentFlag(videoId: String, videoTitle: String, creatorName: String, creatorId: String, violationType: String, confidence: Int, thumbnailURL: String? = nil) async {
        // Dedup: don't flag the same video twice
        let existing = try? await db.collection("contentFlags")
            .whereField("videoId", isEqualTo: videoId)
            .whereField("reviewed", isEqualTo: false)
            .getDocuments()

        guard existing?.documents.isEmpty != false else { return }

        let data: [String: Any] = [
            "videoId": videoId,
            "videoTitle": videoTitle,
            "creatorName": creatorName,
            "creatorId": creatorId,
            "violationType": violationType,
            "confidence": confidence,
            "timestamp": Timestamp(date: Date()),
            "reviewed": false,
            "source": "PlatformMonitorService"
        ]
        do {
            try await db.collection("contentFlags").addDocument(data: data)
            contentFlagged += 1
            print("🚩 [Content] \(violationType) — '\(videoTitle.prefix(40))'")

            // Write the evidence record the 3-Strike review sheet actually displays
            // (StrikeCaseReviewSheet queries `flaggedContent` by userId) — without this,
            // "FLAGGED CONTENT EVIDENCE" is always empty for AI-detected violations.
            if !creatorId.isEmpty {
                var evidence: [String: Any] = [
                    "userId": creatorId,
                    "title": videoTitle,
                    "reason": violationType,
                    "flaggedAt": Timestamp(date: Date()),
                    "reportCount": 1,
                    "source": "PlatformMonitorService"
                ]
                if let thumbnailURL { evidence["imageURL"] = thumbnailURL }
                try? await db.collection("flaggedContent").addDocument(data: evidence)
            }

            // Auto-queue for 3-Strike review if confidence is high enough
            if confidence >= 85 && !creatorId.isEmpty {
                await autoQueueStrikeCase(
                    userId: creatorId,
                    creatorName: creatorName,
                    violationType: violationType,
                    videoTitle: videoTitle,
                    confidence: confidence,
                    thumbnailURL: thumbnailURL
                )
            }
        } catch {
            print("❌ [PlatformMonitor] Failed to write content flag: \(error)")
        }
    }

    // MARK: - Auto Strike Queue

    private func autoQueueStrikeCase(userId: String, creatorName: String, violationType: String, videoTitle: String, confidence: Int, thumbnailURL: String? = nil) async {
        // Look up user details
        let userSnap = try? await db.collection("users").document(userId).getDocument()
        let username = userSnap?.data()?["username"] as? String
            ?? userSnap?.data()?["displayName"] as? String
            ?? creatorName
        let email = userSnap?.data()?["email"] as? String ?? ""

        // Check if an active case already exists for this user
        let existing = try? await db.collection("strikeCases")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", in: [StrikeCaseStatus.active.rawValue, StrikeCaseStatus.pendingReview.rawValue])
            .getDocuments()

        var violation: [String: Any] = [
            "id": UUID().uuidString,
            "type": violationType,
            "detail": "AI detected '\(violationType)' in: \"\(videoTitle)\" — \(confidence)% confidence.",
            "date": Timestamp(date: Date()),
            "videoTitle": videoTitle,
            "severity": confidence >= 95 ? "critical" : "high",
            "source": "ai"
        ]
        if let thumbnailURL { violation["thumbnailURL"] = thumbnailURL }

        if let existingDoc = existing?.documents.first {
            let currentStrikes = existingDoc.data()["strikeCount"] as? Int ?? 0
            let newStrikes = min(currentStrikes + 1, 3)
            let newStatus: String = newStrikes >= 3
                ? StrikeCaseStatus.suspended.rawValue
                : StrikeCaseStatus.pendingReview.rawValue
            try? await existingDoc.reference.updateData([
                "violations": FieldValue.arrayUnion([violation]),
                "strikeCount": newStrikes,
                "latestViolation": violationType,
                "lastActivity": Timestamp(date: Date()),
                "status": newStatus,
                "aiRiskScore": min(100, newStrikes * 33 + confidence / 5)
            ])
            print("⚖️ [StrikeQueue] Updated case for \(username) — strike \(newStrikes)/3")
        } else {
            let aiRisk = min(100, 30 + confidence / 3)
            let userData = userSnap?.data() ?? [:]
            let profileImageURL = userData["profileImageURL"] as? String
                ?? userData["photoURL"] as? String
                ?? userData["avatarURL"] as? String
            var newCase: [String: Any] = [
                "userId": userId,
                "username": username,
                "email": email,
                "joinDate": userData["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
                "videoCount": userData["videoCount"] as? Int ?? 0,
                "followerCount": userData["subscriberCount"] as? Int ?? userData["followerCount"] as? Int ?? 0,
                "strikeCount": 1,
                "status": StrikeCaseStatus.pendingReview.rawValue,
                "violations": [violation],
                "latestViolation": violationType,
                "lastActivity": Timestamp(date: Date()),
                "aiRiskScore": aiRisk,
                "aiRiskSummary": "AI flagged this account for \(violationType) (\(confidence)% confidence). Risk score: \(aiRisk)%.",
                "aiRecommendation": aiRisk > 65 ? "Issue Strike" : "Give Warning",
                "ownerNotes": "",
                "ownerMessages": []
            ]
            if let pic = profileImageURL { newCase["profileImageURL"] = pic }
            try? await db.collection("strikeCases").addDocument(data: newCase)
            print("⚖️ [StrikeQueue] New case created for \(username) — \(violationType)")
        }
    }

    // MARK: - Violation Detector

    private struct ViolationResult {
        let type: String
        let confidence: Int
    }

    private func detectViolation(in text: String) -> ViolationResult? {
        let rules: [(keywords: [String], type: String, confidence: Int)] = [
            // NSFW
            (["nude", "naked", "xxx", "porn", "onlyfans", "explicit", "nsfw", "adult content"], "NSFW Content", 95),
            // Hate Speech
            (["kill all", "die nigger", "white power", "nazi", "kys yourself", "go kill", "hate jews", "hate blacks", "hate whites", "faggot", "retard"], "Hate Speech", 92),
            // Violence
            (["how to make a bomb", "how to kill", "shoot up", "mass shooting", "school shooting", "terrorist", "jihad attack"], "Violence / Terrorism", 98),
            // Spam
            (["subscribe 4 subscribe", "sub4sub", "free followers", "buy followers", "click here for free", "make money fast", "get rich quick"], "Spam", 85),
            // Self-harm
            (["how to commit suicide", "suicide method", "cut yourself", "self harm tutorial", "overdose tutorial"], "Self-Harm", 97),
            // Scam
            (["send bitcoin", "wire transfer", "crypto giveaway", "double your money", "investment opportunity", "send money"], "Scam / Fraud", 88),
            // Copyright bait
            (["full movie free", "watch movies free", "leaked album", "pirated", "cracked software", "warez"], "Copyright Violation", 80),
        ]

        for rule in rules {
            for keyword in rule.keywords {
                if text.contains(keyword) {
                    return ViolationResult(type: rule.type, confidence: rule.confidence)
                }
            }
        }
        return nil
    }
}

// MARK: - Extension: Int formatting helper

private extension Int {
    func formatted() -> String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
