//
//  SafetyAgents.swift
//  MyChannel
//
//  5 Safety AGI Agents for content moderation and platform safety
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Import shared agent types
// AgentMetrics, AgentStatus, ModerationResult, Severity are now in SharedAgentTypes.swift

// MARK: - 1. Content Moderation AI

@MainActor
final class ContentModerationAI: ObservableObject {
    
    static let shared = ContentModerationAI()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var moderationQueue: [ModerationItem] = []
    
    let config: AGIAgentConfig = .init(
        id: "content-moderation-ai",
        name: "Content Moderation AI",
        category: .safety,
        status: .planned,
        description: "AI-powered content moderation for videos, comments, and user-generated content",
        impactDescription: "Save $50M in moderation costs",
        estimatedRevenue: "+$50M saved",
        vertexAIAgentId: nil,
        promptTemplate: "Moderate content for safety violations",
        requiredDataSources: ["Video Content", "Comments", "Reports"],
        outputFormat: "JSON moderation decisions",
        isEnabled: false,
        priority: 1,
        estimatedBuildTime: "4 weeks",
        runInterval: 30
    )
    
    private var errorCount: Int = 0
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Content Moderation AI] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                handleError(error)
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // 1. Check recent uploads
        let cutoff = Date().addingTimeInterval(-5 * 60) // Last 5 minutes
        let videoSnapshot = try await db.collection("videos")
            .whereField("createdAt", isGreaterThan: cutoff)
            .whereField("moderated", isEqualTo: false)
            .getDocuments()
        
        print("🛡️ [Content Mod] Moderating \(videoSnapshot.documents.count) new videos")
        
        for doc in videoSnapshot.documents {
            let videoId = doc.documentID
            let data = doc.data()
            let title = data["title"] as? String ?? ""
            let description = data["description"] as? String ?? ""
            let thumbnailURL = data["thumbnailURL"] as? String ?? ""
            
            // 2. Run AI moderation
            let result = try await moderateContent(
                title: title,
                description: description,
                thumbnailURL: thumbnailURL
            )
            
            // 3. Take action based on result
            if !result.isApproved {
                try await flagContent(videoId: videoId, reason: result.reason ?? "Policy violation", severity: result.severity)
            } else {
                try await approveContent(videoId: videoId)
            }
            
            metrics.impressions += 1
        }
        
        // 4. Moderate recent comments
        let commentSnapshot = try await db.collection("comments")
            .whereField("createdAt", isGreaterThan: cutoff)
            .whereField("moderated", isEqualTo: false)
            .getDocuments()
        
        print("💬 [Content Mod] Moderating \(commentSnapshot.documents.count) new comments")
        
        for doc in commentSnapshot.documents {
            let commentId = doc.documentID
            let text = doc.data()["text"] as? String ?? ""
            
            let result = try await moderateText(text: text)
            
            if !result.isApproved {
                try await removeComment(commentId: commentId, reason: result.reason ?? "Policy violation")
            } else {
                try await approveComment(commentId: commentId)
            }
        }
        
        metrics.totalRuns += 1
        #endif
    }
    
    // MARK: - AI Moderation
    private func moderateContent(title: String, description: String, thumbnailURL: String) async throws -> ModerationResult {
        // Use Anthropic Claude for content moderation
        let prompt = """
        Moderate this video content:
        Title: \(title)
        Description: \(description)
        
        Check for:
        - Hate speech
        - Violence or gore
        - Sexual content
        - Harassment or bullying
        - Dangerous activities
        - Misinformation
        - Spam
        
        Respond with JSON: {"violates": bool, "reason": string, "severity": "low|medium|high|critical"}
        """
        
        let response = try await AnthropicService.shared.sendMessage(prompt)
        
        // Parse AI response
        if response.contains("\"violates\": true") || response.contains("inappropriate") {
            return ModerationResult(
                isApproved: false,
                confidence: 0.85,
                flaggedContent: ["Policy violation detected"],
                severity: .medium,
                reason: "Potential policy violation detected"
            )
        }
        
        return ModerationResult(isApproved: true, confidence: 0.95, flaggedContent: [], severity: .none, reason: nil)
    }
    
    private func moderateText(text: String) async throws -> ModerationResult {
        // Simple toxicity check (TODO: integrate proper sentiment analysis)
        let toxicWords = ["hate", "kill", "die", "stupid", "idiot", "scam", "fake"]
        let lowerText = text.lowercased()
        let hasToxicity = toxicWords.contains { lowerText.contains($0) }
        
        if hasToxicity {
            return ModerationResult(
                isApproved: false,
                confidence: 0.75,
                flaggedContent: ["Potential toxic content"],
                severity: .high,
                reason: "High toxicity detected"
            )
        }
        
        return ModerationResult(isApproved: true, confidence: 0.90, flaggedContent: [], severity: .none, reason: nil)
    }
    
    // MARK: - Actions
    private func flagContent(videoId: String, reason: String, severity: ModerationResult.Severity) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("videos").document(videoId).updateData([
            "flagged": true,
            "flagReason": reason,
            "flagSeverity": severity.rawValue,
            "moderated": true,
            "visible": severity != .critical, // Hide critical violations immediately
            "moderatedAt": FieldValue.serverTimestamp()
        ])
        
        print("🚨 [Content Mod] Flagged video \(videoId): \(reason)")
        
        // Notify admins for review
        await notifyAdmins(contentId: videoId, reason: reason, severity: severity)
        #endif
    }
    
    private func approveContent(videoId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("videos").document(videoId).updateData([
            "moderated": true,
            "approved": true,
            "moderatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    private func removeComment(commentId: String, reason: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("comments").document(commentId).updateData([
            "removed": true,
            "removeReason": reason,
            "moderated": true
        ])
        print("🗑️ [Content Mod] Removed comment \(commentId)")
        #endif
    }
    
    private func approveComment(commentId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("comments").document(commentId).updateData([
            "moderated": true,
            "approved": true
        ])
        #endif
    }
    
    private func notifyAdmins(contentId: String, reason: String, severity: ModerationResult.Severity) async {
        // Writes to admin_alerts — same pattern as other notification TODOs
        print("⚠️ [Admin Alert] Content \(contentId) flagged for: \(reason) (\(severity.rawValue))")
        // await NotificationManager.shared.sendAdminAlert(
        //     title: "⚠️ Content Flagged",
        //     message: "Content \(contentId) flagged for: \(reason) (\(severity.rawValue))",
        //     priority: severity == .critical ? .high : .medium
        // )
    }
    
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [Content Mod] Error: \(error.localizedDescription)")
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Content Moderation AI] Agent deallocated")
    }
}

// MARK: - 2. Copyright Protector

@MainActor
final class CopyrightProtector: ObservableObject {
    
    static let shared = CopyrightProtector()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    
    let config: AGIAgentConfig = .init(
        id: "copyright-protector",
        name: "Copyright Protector",
        category: .safety,
        status: .planned,
        description: "Detects and handles copyright violations using Content ID",
        impactDescription: "Save $100M in copyright disputes",
        estimatedRevenue: "+$100M saved",
        vertexAIAgentId: nil,
        promptTemplate: "Detect and prevent copyright violations",
        requiredDataSources: ["Content ID", "Copyright Database", "Video Metadata"],
        outputFormat: "JSON copyright violations",
        isEnabled: false,
        priority: 2,
        estimatedBuildTime: "5 weeks",
        runInterval: 300
    )
    
    private var errorCount: Int = 0
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Copyright Protector] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        // Copyright scanning is triggered per-video upload via ContentIDService.scanForMatches
        // This agent monitors and logs overall activity
        let activeMatches = ContentIDService.shared.activeMatches
        
        for match in activeMatches where match.status == .active {
            try await handleCopyrightMatch(videoId: match.matchedVideoId, owner: match.rightsholder)
        }
        
        metrics.totalRuns += 1
        print("©️ [Copyright] Checked active matches - \(activeMatches.count) total")
        #endif
    }
    
    private func handleCopyrightMatch(videoId: String, owner: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Option 1: Mute audio (for music)
        // Option 2: Monetize for owner
        // Option 3: Block video
        
        try await db.collection("videos").document(videoId).updateData([
            "copyrightClaim": true,
            "copyrightOwner": owner,
            "claimAction": "monetize_for_owner",
            "claimedAt": FieldValue.serverTimestamp()
        ])
        
        print("©️ [Copyright] Claimed video \(videoId) for \(owner)")
        #endif
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Copyright Protector] Agent deallocated")
    }
}

// MARK: - 3. Spam Destroyer

@MainActor
final class SpamDestroyer: ObservableObject {
    
    static let shared = SpamDestroyer()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    
    let config: AGIAgentConfig = .init(
        id: "spam-destroyer",
        name: "Spam Destroyer",
        category: .safety,
        status: .planned,
        description: "Detects and removes spam accounts and content",
        impactDescription: "+90% spam reduction",
        estimatedRevenue: "+$10M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Detect and eliminate spam",
        requiredDataSources: ["User Behavior", "Comment Patterns", "Spam Signatures"],
        outputFormat: "JSON spam detection results",
        isEnabled: false,
        priority: 3,
        estimatedBuildTime: "2 weeks",
        runInterval: 180
    )
    
    private var errorCount: Int = 0
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Spam Destroyer] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Detect spam patterns:
        // 1. Rapid commenting (>10 comments in 1 minute)
        // 2. Duplicate comments
        // 3. Link spam
        // 4. Bot-like behavior
        
        let cutoff = Date().addingTimeInterval(-5 * 60)
        let snapshot = try await db.collection("comments")
            .whereField("createdAt", isGreaterThan: cutoff)
            .getDocuments()
        
        // Group by user
        var userComments: [String: [String]] = [:]
        for doc in snapshot.documents {
            let userId = doc.data()["userId"] as? String ?? ""
            let text = doc.data()["text"] as? String ?? ""
            userComments[userId, default: []].append(text)
        }
        
        // Check for spam
        for (userId, comments) in userComments {
            // Rapid commenting
            if comments.count > 10 {
                try await flagSpammer(userId: userId, reason: "Rapid commenting (\(comments.count) in 5min)")
            }
            
            // Duplicate comments
            let unique = Set(comments)
            if unique.count < comments.count / 2 {
                try await flagSpammer(userId: userId, reason: "Duplicate spam")
            }
        }
        
        metrics.totalRuns += 1
        print("🚫 [Spam] Checked \(userComments.count) users")
        #endif
    }
    
    private func flagSpammer(userId: String, reason: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try await db.collection("users").document(userId).updateData([
            "flaggedAsSpam": true,
            "spamReason": reason,
            "restricted": true,
            "restrictedAt": FieldValue.serverTimestamp()
        ])
        
        // Remove all recent comments
        let comments = try await db.collection("comments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in comments.documents {
            try await doc.reference.delete()
        }
        
        print("🚫 [Spam] Banned spammer \(userId): \(reason)")
        metrics.impressions += 1
        #endif
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Spam Destroyer] Agent deallocated")
    }
}

// MARK: - 4. Toxicity Filter

@MainActor
final class ToxicityFilter: ObservableObject {
    
    static let shared = ToxicityFilter()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    
    let config: AGIAgentConfig = .init(
        id: "toxicity-filter",
        name: "Toxicity Filter",
        category: .safety,
        status: .planned,
        description: "Filters toxic and harmful language in real-time",
        impactDescription: "+95% toxicity reduction",
        estimatedRevenue: "+$20M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Filter toxic content in real-time",
        requiredDataSources: ["Comments", "Chat Messages", "Toxicity Patterns"],
        outputFormat: "JSON toxicity scores",
        isEnabled: false,
        priority: 4,
        estimatedBuildTime: "3 weeks",
        runInterval: 60
    )
    
    private var errorCount: Int = 0
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Toxicity Filter] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Check live chat messages for toxicity
        let cutoff = Date().addingTimeInterval(-2 * 60) // Last 2 minutes
        let snapshot = try await db.collection("live-chat")
            .whereField("timestamp", isGreaterThan: cutoff)
            .whereField("filtered", isEqualTo: false)
            .getDocuments()
        
        print("🔍 [Toxicity] Filtering \(snapshot.documents.count) messages")
        
        for doc in snapshot.documents {
            _ = doc.documentID // messageId - for future logging
            let text = doc.data()["text"] as? String ?? ""
            let userId = doc.data()["userId"] as? String ?? ""
            
            // Simple toxicity check (TODO: integrate proper sentiment analysis)
            let toxicWords = ["hate", "kill", "die", "stupid", "idiot", "scam", "fake"]
            let lowerText = text.lowercased()
            let isToxic = toxicWords.contains { lowerText.contains($0) }
            
            if isToxic {
                // Remove toxic message
                try await doc.reference.updateData([
                    "removed": true,
                    "toxicityScore": 0.8,
                    "filtered": true
                ])
                
                // Warn or timeout user
                try await timeoutUser(userId: userId, duration: 300) // 5 min timeout
                
                print("⚠️ [Toxicity] Removed toxic message from \(userId)")
                metrics.impressions += 1
            } else {
                try await doc.reference.updateData(["filtered": true])
            }
        }
        
        metrics.totalRuns += 1
        #endif
    }
    
    private func timeoutUser(userId: String, duration: TimeInterval) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let until = Date().addingTimeInterval(duration)
        
        try await db.collection("users").document(userId).updateData([
            "timedOut": true,
            "timeoutUntil": Timestamp(date: until)
        ])
        
        print("⏰ [Toxicity] Timed out user \(userId) for \(Int(duration))s")
        #endif
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Toxicity Filter] Agent deallocated")
    }
}

// MARK: - 5. Real-Time Report Handler

@MainActor
final class RealTimeReportHandler: ObservableObject {
    
    static let shared = RealTimeReportHandler()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var pendingReports: [Report] = []
    
    let config: AGIAgentConfig = .init(
        id: "report-handler",
        name: "Real-Time Report Handler",
        category: .safety,
        status: .planned,
        description: "Processes user reports and takes immediate action",
        impactDescription: "+99% report response time",
        estimatedRevenue: "+$15M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Process and act on user reports instantly",
        requiredDataSources: ["User Reports", "Historical Violations", "Context Data"],
        outputFormat: "JSON report resolutions",
        isEnabled: false,
        priority: 5,
        estimatedBuildTime: "2 weeks",
        runInterval: 30
    )
    
    private var errorCount: Int = 0
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Report Handler] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        // Client agents may observe queue depth for diagnostics, but moderation
        // decisions and content mutations are server-authoritative.
        let snapshot = try await Firestore.firestore()
            .collection("content_reports")
            .whereField("status", isEqualTo: "pending")
            .limit(to: 50)
            .getDocuments()

        print("📋 [Report Handler] Observed \(snapshot.documents.count) pending reports")
        metrics.impressions += snapshot.documents.count
        metrics.totalRuns += 1
        #endif
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Report Handler] Agent deallocated")
    }
}

// MARK: - Supporting Models

// Note: ModerationItem, ModerationResult, Report, Severity, AgentMetrics, AgentStatus
// are now in SharedAgentTypes.swift

