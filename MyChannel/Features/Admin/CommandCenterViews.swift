// ⚡ PERFORMANCE: Extracted from OwnerCommandCenterView.swift — independent compilation unit.
// Stat cards, metric cards, row views, and ViewModel compile in parallel.
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Supporting Views

struct CCHeaderStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CCMetricCard: View {
    let title: String; let value: String; let subtitle: String; let color: Color; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
                Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
            }
            Text(value).font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
            Text(subtitle).font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}

struct DepartmentRow: View {
    let dept: Department
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(dept.statusColor).frame(width: 6, height: 6)
            Text(dept.name).font(.system(size: 13, weight: .medium)).foregroundColor(CCTheme.textPrimary)
            Spacer()
            Text(dept.status).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(dept.statusColor)
            Text(dept.metric).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(CCTheme.panel).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}

struct PlatformEventRow: View {
    let event: PlatformEvent
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: event.icon).font(.system(size: 12)).foregroundColor(event.color).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 12, weight: .semibold)).foregroundColor(CCTheme.textPrimary)
                Text(event.detail).font(.system(size: 11)).foregroundColor(CCTheme.textSecondary).lineLimit(2)
            }
            Spacer()
            Text(event.timestamp, style: .relative).font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
        }
        .padding(8).background(CCTheme.panel).cornerRadius(8)
    }
}

struct FraudAlertRow: View {
    let alert: FraudAlert
    let onReview: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill").foregroundColor(CCTheme.critical)
                Text(alert.type.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.critical)
                Spacer()
                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                if !alert.reviewed {
                    Text("NEW").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(CCTheme.critical).cornerRadius(4)
                }
            }
            Text(alert.description).font(.system(size: 12)).foregroundColor(CCTheme.textPrimary)
            HStack {
                Label(alert.amount, systemImage: "dollarsign.circle").font(.system(size: 11)).foregroundColor(CCTheme.warning)
                Spacer()
                Text("User: \(alert.userId)").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                if !alert.reviewed {
                    Button("MARK REVIEWED", action: onReview)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.good)
                }
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(alert.reviewed ? CCTheme.panelBorder : CCTheme.critical.opacity(0.35), lineWidth: 1))
    }
}

struct ContentFlagRow: View {
    let flag: ContentFlag
    let onApprove: () -> Void
    let onRemove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(CCTheme.warning)
                Text(flag.violationType.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.warning)
                Spacer()
                Text(flag.timestamp, style: .relative)
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                if !flag.reviewed {
                    Text("PENDING").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(CCTheme.warning).cornerRadius(4)
                }
            }
            Text("Video: \(flag.videoTitle)").font(.system(size: 13, weight: .semibold)).foregroundColor(CCTheme.textPrimary)
            Text("Creator: \(flag.creatorName)").font(.system(size: 11)).foregroundColor(CCTheme.textSecondary)
            Text("AI Confidence: \(flag.confidence)%").font(.system(size: 11, design: .monospaced)).foregroundColor(CCTheme.warning)
            if !flag.reviewed {
                HStack(spacing: 10) {
                    Button("APPROVE", action: onApprove)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.good)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(CCTheme.good.opacity(0.12)).cornerRadius(8)
                    Button("REMOVE", action: onRemove)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.critical)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(CCTheme.critical.opacity(0.12)).cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(flag.reviewed ? CCTheme.panelBorder : CCTheme.warning.opacity(0.35), lineWidth: 1))
    }
}

struct DailyReportCard: View {
    let report: DailyReport
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { expanded.toggle() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.date, style: .date)
                            .font(.system(size: 15, weight: .bold)).foregroundColor(CCTheme.textPrimary)
                        HStack(spacing: 12) {
                            scoreLabel("HEALTH", "\(Int(report.healthScore))%", report.healthScore >= 80 ? CCTheme.good : CCTheme.warning)
                            scoreLabel("USERS", "+\(report.newUsers)", CCTheme.textPrimary)
                            scoreLabel("REVENUE", "$\(report.revenue)", CCTheme.good)
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(CCTheme.textSecondary)
                }
            }
            if expanded {
                Divider()
                Text(report.summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(CCTheme.textPrimary).lineSpacing(4)
                if !report.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIGHLIGHTS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        ForEach(report.highlights, id: \.self) { h in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 8)).foregroundColor(CCTheme.good)
                                Text(h).font(.system(size: 12)).foregroundColor(CCTheme.textPrimary)
                            }
                        }
                    }
                }
                if !report.concerns.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONCERNS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        ForEach(report.concerns, id: \.self) { c in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 8)).foregroundColor(CCTheme.warning)
                                Text(c).font(.system(size: 12)).foregroundColor(CCTheme.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(CCTheme.panel).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    private func scoreLabel(_ title: String, _ val: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(val).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(title).font(.system(size: 8, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
        }
    }
}


// MARK: - Data Models
// ⚡ Moved to CommandCenterModels.swift for independent compilation

// MARK: - ViewModel

@MainActor
class CommandCenterViewModel: ObservableObject {
    // User Stats
    @Published var totalUsers: Int = 0
    @Published var totalDownloads: Int = 0
    @Published var newUsersToday: Int = 0
    @Published var newDownloadsToday: Int = 0
    @Published var newDownloadsWeek: Int = 0
    @Published var newDownloadsMonth: Int = 0
    @Published var activeNow: Int = 0
    @Published var paidUsers: Int = 0
    @Published var creatorCount: Int = 0
    @Published var newCreatorsToday: Int = 0
    @Published var day1Retention: Int = 0
    @Published var day7Retention: Int = 0
    @Published var avgSessionMinutes: Int = 0
    @Published var topCountries: [CountryStat] = []

    // Revenue
    @Published var revenueToday: Int = 0

    // Platform Health
    @Published var platformHealth: Double = 92.0

    // Content
    @Published var videosUploaded: Int = 0
    @Published var videosUploadedToday: Int = 0
    @Published var contentFlags: [ContentFlag] = []
    @Published var contentRemovedToday: Int = 0

    // Fraud
    @Published var fraudAlerts: [FraudAlert] = []
    @Published var fraudBlockedAmount: Int = 0

    // Events & Departments
    @Published var recentEvents: [PlatformEvent] = []
    @Published var departments: [Department] = []

    // AI Briefing
    @Published var dailySummary: String = ""
    @Published var summaryGeneratedAt: Date = Date()
    @Published var isGeneratingBriefing = false

    // Reports
    @Published var dailyReports: [DailyReport] = []
    @Published var isGeneratingReport = false

    // 3-Strike Queue
    @Published var strikeQueueCount: Int = 0

    // Autopilot & creator health
    @Published var autopilotStatus: SelfHealingAIStatus = .placeholder
    @Published var creatorHealth: [CreatorPulse] = []
    @Published var strikeSnapshots: [StrikeSnapshot] = []
    @Published var ownerTasks: [OwnerTask] = []

    var hasOpenModerationItems: Bool {
        !openFraudAlerts.isEmpty || !openContentFlags.isEmpty
    }

    var openFraudAlerts: [FraudAlert] {
        fraudAlerts.filter { !$0.reviewed }
    }

    var openContentFlags: [ContentFlag] {
        contentFlags.filter { !$0.reviewed }
    }

    private var db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var refreshTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    
    // Owner UIDs for access control
    private let ownerUIDs = [
        "7EAoUc1aKsNRqR4cYBIOYVGB3Mf2"  // keontapeat@mychannel.live
    ]

    func startTracking() {
        loadFromFirestore()
        setupRealTimeListeners()
        setupDepartments()
        setupSampleEvents()
        // Auto-generate briefing on start
        Task { await generateDailyBriefing() }
        SelfHealingAIService.shared.startMonitoring()
        SelfHealingAIService.shared.$status
            .receive(on: RunLoop.main)
            .assign(to: &$autopilotStatus)
        setupOwnerTasks()
        setupCreatorHealth()
        setupStrikeSnapshots()
        // Refresh every 60 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadFromFirestore()
                self?.setupCreatorHealth()
                self?.setupStrikeSnapshots()
            }
        }
    }

    func stopTracking() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
        SelfHealingAIService.shared.stopMonitoring()
        cancellables.removeAll()
    }

    // MARK: - Firestore Loading

    func loadFromFirestore() {
        // Verify owner access
        guard let currentUser = Auth.auth().currentUser,
              ownerUIDs.contains(currentUser.uid) else {
            print("🚫 [CommandCenter] Access denied - not an owner")
            return
        }
        
        // Load analytics from dedicated analytics collection
        db.collection("platformAnalytics").document("daily").getDocument { [weak self] snap, _ in
            guard let self else { return }
            let data = snap?.data() ?? [:]
            Task { @MainActor in
                self.totalUsers = data["totalUsers"] as? Int ?? 0
                self.totalDownloads = data["totalDownloads"] as? Int ?? 0
                self.newUsersToday = data["newUsersToday"] as? Int ?? 0
                self.newDownloadsToday = data["newDownloadsToday"] as? Int ?? 0
                self.newDownloadsWeek = data["newDownloadsWeek"] as? Int ?? 0
                self.newDownloadsMonth = data["newDownloadsMonth"] as? Int ?? 0
                self.activeNow = data["activeNow"] as? Int ?? 0
                self.paidUsers = data["paidUsers"] as? Int ?? 0
                self.creatorCount = data["creatorCount"] as? Int ?? 0
                self.newCreatorsToday = data["newCreatorsToday"] as? Int ?? 0
                self.day1Retention = data["day1Retention"] as? Int ?? 0
                self.day7Retention = data["day7Retention"] as? Int ?? 0
                self.avgSessionMinutes = data["avgSessionMinutes"] as? Int ?? 0
                self.revenueToday = data["revenueToday"] as? Int ?? 0
                self.platformHealth = data["platformHealth"] as? Double ?? 92.0

                if let countriesData = data["topCountries"] as? [[String: Any]] {
                    self.topCountries = countriesData.compactMap { dict -> CountryStat? in
                        guard let name = dict["name"] as? String,
                              let flag = dict["flag"] as? String,
                              let users = dict["users"] as? Int,
                              let percent = dict["percent"] as? Int else { return nil }
                        return CountryStat(flag: flag, name: name, users: users, percent: percent)
                    }
                }
            }
        }

        // Load videos
        db.collection("videos").getDocuments { [weak self] snap, _ in
            guard let self else { return }
            let count = snap?.documents.count ?? 0
            Task { @MainActor in
                self.videosUploaded = count
                self.videosUploadedToday = max(0, count / 20)
            }
        }

        // Load fraud alerts from Firestore
        db.collection("fraudAlerts")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snap, _ in
                guard let self else { return }
                let alerts = snap?.documents.compactMap { doc -> FraudAlert? in
                    let data = doc.data()
                    guard let type = data["type"] as? String,
                          let desc = data["description"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return FraudAlert(
                        id: doc.documentID,
                        type: type,
                        description: desc,
                        amount: data["amount"] as? String ?? "$0",
                        userId: data["userId"] as? String ?? "unknown",
                        timestamp: ts,
                        reviewed: data["reviewed"] as? Bool ?? false
                    )
                } ?? []
                Task { @MainActor in
                    self.fraudAlerts = alerts
                    self.fraudBlockedAmount = alerts.reduce(0) { sum, a in
                        let val = Int(a.amount.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
                        return sum + val
                    }
                }
            }

        // Load content flags from Firestore
        db.collection("contentFlags")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snap, _ in
                guard let self else { return }
                let flags = snap?.documents.compactMap { doc -> ContentFlag? in
                    let data = doc.data()
                    guard let videoTitle = data["videoTitle"] as? String,
                          let violation = data["violationType"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return ContentFlag(
                        id: doc.documentID,
                        videoTitle: videoTitle,
                        creatorName: data["creatorName"] as? String ?? "Unknown Creator",
                        violationType: violation,
                        confidence: data["confidence"] as? Int ?? 90,
                        timestamp: ts,
                        reviewed: data["reviewed"] as? Bool ?? false
                    )
                } ?? []
                Task { @MainActor in
                    self.contentFlags = flags
                    self.contentRemovedToday = flags.filter { $0.reviewed }.count
                }
            }
    }

    // MARK: - Real-time Listeners

    func setupRealTimeListeners() {
        // Listen for new fraud alerts in real time
        let fraudListener = db.collection("fraudAlerts")
            .whereField("reviewed", isEqualTo: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let newAlerts = snap.documents.compactMap { doc -> FraudAlert? in
                    let data = doc.data()
                    guard let type = data["type"] as? String,
                          let desc = data["description"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return FraudAlert(
                        id: doc.documentID, type: type, description: desc,
                        amount: data["amount"] as? String ?? "$0",
                        userId: data["userId"] as? String ?? "unknown",
                        timestamp: ts, reviewed: false
                    )
                }
                Task { @MainActor in
                    // Merge with existing reviewed ones
                    let reviewed = self.fraudAlerts.filter { $0.reviewed }
                    self.fraudAlerts = (newAlerts + reviewed).sorted { $0.timestamp > $1.timestamp }
                }
            }
        listeners.append(fraudListener)

        // Listen for new content flags
        let contentListener = db.collection("contentFlags")
            .whereField("reviewed", isEqualTo: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let newFlags = snap.documents.compactMap { doc -> ContentFlag? in
                    let data = doc.data()
                    guard let videoTitle = data["videoTitle"] as? String,
                          let violation = data["violationType"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return ContentFlag(
                        id: doc.documentID, videoTitle: videoTitle,
                        creatorName: data["creatorName"] as? String ?? "Unknown",
                        violationType: violation, confidence: data["confidence"] as? Int ?? 90,
                        timestamp: ts, reviewed: false
                    )
                }
                Task { @MainActor in
                    let reviewed = self.contentFlags.filter { $0.reviewed }
                    self.contentFlags = (newFlags + reviewed).sorted { $0.timestamp > $1.timestamp }
                }
            }
        listeners.append(contentListener)

        // Listen for pending strike cases
        let strikeListener = db.collection("strikeCases")
            .whereField("status", isEqualTo: "pendingReview")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let count = snap?.documents.count ?? 0
                Task { @MainActor in self.strikeQueueCount = count }
            }
        listeners.append(strikeListener)
    }

    // MARK: - Actions

    func reviewFraudAlert(_ id: String) {
        db.collection("fraudAlerts").document(id).updateData(["reviewed": true])
        if let idx = fraudAlerts.firstIndex(where: { $0.id == id }) {
            fraudAlerts[idx].reviewed = true
        }
        setupStrikeSnapshots()
    }

    enum ContentAction { case approve, remove }

    func reviewContentFlag(_ id: String, action: ContentAction) {
        db.collection("contentFlags").document(id).updateData([
            "reviewed": true,
            "action": action == .approve ? "approved" : "removed"
        ])
        if let idx = contentFlags.firstIndex(where: { $0.id == id }) {
            contentFlags[idx].reviewed = true
        }
        if action == .remove { contentRemovedToday += 1 }
        setupStrikeSnapshots()
    }

    func addSampleTask() {
        let task = OwnerTask(
            title: "Call top creator",
            detail: "Give @NovaVision a surprise bonus for 3M views streak",
            createdAt: Date()
        )
        ownerTasks.append(task)
    }

    func completeTask(_ id: UUID) {
        ownerTasks.removeAll { $0.id == id }
    }

    func focusStrikeCase(id: String) {
        print("👁️ Opening strike case \(id)")
    }

    func refreshUserData() async {
        loadFromFirestore()
    }

    // MARK: - AI Briefing via Gemini

    func generateDailyBriefing() async {
        isGeneratingBriefing = true
        defer { isGeneratingBriefing = false }
        let prompt = """
        You are the Chief AI Officer for MyChannel, a next-gen video platform.
        Write a brief 3-paragraph executive daily briefing for the owner (Keonta).

        Platform Stats Today:
        - Total Users: \(formatNumber(totalUsers))
        - New Users Today: +\(formatNumber(newUsersToday))
        - Active Right Now: \(formatNumber(activeNow))
        - Videos Uploaded: \(formatNumber(videosUploaded))
        - Platform Health: \(Int(platformHealth))%
        - Fraud Alerts: \(fraudAlerts.count) (\(fraudAlerts.filter { !$0.reviewed }.count) unreviewed)
        - Content Flags: \(contentFlags.count) (\(contentFlags.filter { !$0.reviewed }.count) pending)
        - Revenue Today: $\(formatNumber(revenueToday))

        Write a concise, data-driven briefing covering:
        1. Overall platform performance today
        2. Key risks or issues to address
        3. One strategic recommendation

        Be direct, brief, and CEO-level. Use $ and % where relevant.
        """
        let key = AppSecrets.googleCloudAPIKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(key)") else {
            dailySummary = "Configure GOOGLE_CLOUD_API_KEY to enable AI briefings."
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]], "generationConfig": ["maxOutputTokens": 400]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                dailySummary = text.trimmingCharacters(in: .whitespacesAndNewlines)
                summaryGeneratedAt = Date()
            }
        } catch {
            dailySummary = "Briefing generation failed: \(error.localizedDescription)"
        }
    }

    func generateDailyReport() async {
        isGeneratingReport = true
        defer { isGeneratingReport = false }
        let prompt = """
        You are a data analyst for MyChannel. Generate a concise daily report for \(Date().formatted(date: .long, time: .omitted)).

        Stats:
        - Total Users: \(formatNumber(totalUsers)), New Today: +\(formatNumber(newUsersToday))
        - Revenue Today: $\(formatNumber(revenueToday))
        - Platform Health: \(Int(platformHealth))%
        - Videos Uploaded Total: \(formatNumber(videosUploaded)), Today: +\(videosUploadedToday)
        - Fraud Alerts: \(fraudAlerts.count), Content Flags: \(contentFlags.count)
        - Active Users: \(formatNumber(activeNow))

        Provide a report with:
        1. 2-3 sentence SUMMARY of today's performance
        2. 3 HIGHLIGHTS (good things)
        3. 2 CONCERNS (things to watch)

        Format exactly as:
        SUMMARY: [text]
        HIGHLIGHT: [text]
        HIGHLIGHT: [text]
        HIGHLIGHT: [text]
        CONCERN: [text]
        CONCERN: [text]
        """
        let key = AppSecrets.googleCloudAPIKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(key)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]], "generationConfig": ["maxOutputTokens": 500]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else { return }

            let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var summary = ""; var highlights: [String] = []; var concerns: [String] = []
            for line in lines {
                if line.hasPrefix("SUMMARY:") { summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
                else if line.hasPrefix("HIGHLIGHT:") { highlights.append(String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)) }
                else if line.hasPrefix("CONCERN:") { concerns.append(String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)) }
            }
            if summary.isEmpty { summary = text }
            let report = DailyReport(
                date: Date(), healthScore: platformHealth,
                newUsers: newUsersToday, revenue: formatNumber(revenueToday),
                summary: summary, highlights: highlights, concerns: concerns
            )
            dailyReports.insert(report, at: 0)
        } catch {}
    }

    // MARK: - Helpers

    private func setupDepartments() {
        let monitor = PlatformMonitorService.shared
        departments = [
            Department(name: "3-Strike Review", status: strikeQueueCount > 0 ? "NEEDS REVIEW" : "ALL CLEAR", metric: "\(strikeQueueCount) in queue", statusColor: strikeQueueCount > 0 ? CCTheme.critical : CCTheme.good),
            Department(name: "AI Agent Army", status: AGIAgentManager.shared.isSchedulerRunning ? "RUNNING" : "STANDBY", metric: "\(AGIAgentManager.shared.agents.filter { $0.status == .live }.count)/30 LIVE", statusColor: AGIAgentManager.shared.isSchedulerRunning ? CCTheme.good : CCTheme.warning),
            Department(name: "Fraud Detection", status: fraudAlerts.filter { !$0.reviewed }.isEmpty ? "ALL CLEAR" : "ALERT", metric: "\(monitor.fraudCaught) caught today", statusColor: fraudAlerts.filter { !$0.reviewed }.isEmpty ? CCTheme.good : CCTheme.critical),
            Department(name: "Content Moderation", status: contentFlags.filter { !$0.reviewed }.isEmpty ? "CLEAN" : "REVIEW", metric: "\(monitor.contentFlagged) flagged today", statusColor: contentFlags.filter { !$0.reviewed }.isEmpty ? CCTheme.good : CCTheme.warning),
            Department(name: "Platform Monitor", status: monitor.isRunning ? "SCANNING" : "OFFLINE", metric: "\(monitor.totalScansToday) scans today", statusColor: monitor.isRunning ? CCTheme.neutral : CCTheme.critical),
            Department(name: "Growth & Analytics", status: "TRACKING", metric: "+\(formatNumber(newUsersToday))/day", statusColor: CCTheme.neutral),
            Department(name: "Revenue", status: "EARNING", metric: "$\(formatNumber(revenueToday))/day", statusColor: CCTheme.good),
            Department(name: "Creator Studio", status: "ACTIVE", metric: "\(formatNumber(creatorCount)) creators", statusColor: CCTheme.neutral),
        ]
    }

    private func setupSampleEvents() {
        recentEvents = [
            PlatformEvent(title: "New user milestone", detail: "Platform reached \(formatNumber(totalUsers)) registered users", icon: "person.fill.checkmark", color: CCTheme.good, timestamp: Date().addingTimeInterval(-300)),
            PlatformEvent(title: "AI Agents running", detail: "\(AGIAgentManager.shared.agents.filter { $0.isEnabled }.count) agents actively improving the platform", icon: "brain.head.profile", color: CCTheme.neutral, timestamp: Date().addingTimeInterval(-900)),
            PlatformEvent(title: "Content uploaded", detail: "\(videosUploadedToday) new videos uploaded today", icon: "video.fill", color: CCTheme.neutral, timestamp: Date().addingTimeInterval(-1800)),
        ]
    }

    private func setupOwnerTasks() {
        let now = Date()
        let moderationDetail = openContentFlags.isEmpty
            ? "Keep moderation inbox below 10 pending items"
            : "\(openContentFlags.count) flagged videos awaiting decision"
        let fraudDetail = openFraudAlerts.isEmpty
            ? "Verify yesterday's transactions cleared AI review"
            : "\(openFraudAlerts.count) alerts require manual verification"
        let creatorDetail = creatorCount == 0
            ? "Spotlight 3 breakout creators from Stories"
            : "\(formatNumber(creatorCount)) creators live · send appreciation bonus"

        ownerTasks = [
            OwnerTask(
                title: "Clear strike queue",
                detail: strikeQueueCount > 0 ? "\(strikeQueueCount) cases waiting for review" : "Confirm queue is empty before EOD",
                createdAt: now.addingTimeInterval(-1200)
            ),
            OwnerTask(
                title: "Moderation sync",
                detail: moderationDetail,
                createdAt: now.addingTimeInterval(-3600)
            ),
            OwnerTask(
                title: "Fraud + payouts audit",
                detail: fraudDetail,
                createdAt: now.addingTimeInterval(-5400)
            ),
            OwnerTask(
                title: "Creator love",
                detail: creatorDetail,
                createdAt: now.addingTimeInterval(-7200)
            )
        ]
    }

    private func setupCreatorHealth() {
        let trendingViews = max(1_500, newUsersToday * 90)
        let retentionViews = max(900, day7Retention * 25)
        let monetizationViews = max(750, revenueToday / max(1, paidUsers == 0 ? 1 : paidUsers) * 20)

        creatorHealth = [
            CreatorPulse(
                creatorName: "NovaVision",
                status: "Stories streak · \(videosUploadedToday) uploads today",
                viewsDelta: "+\(formatNumber(trendingViews))",
                healthScore: min(100, platformHealth + 6),
                trendEmoji: "🔥",
                isSpike: true
            ),
            CreatorPulse(
                creatorName: "PulseWave",
                status: "Community tab driving \(day7Retention)% week retention",
                viewsDelta: "+\(formatNumber(retentionViews))",
                healthScore: max(48, platformHealth - 6),
                trendEmoji: "📈",
                isSpike: false
            ),
            CreatorPulse(
                creatorName: "Studio Atlas",
                status: "Live shopping beta pushing ARPU",
                viewsDelta: "+\(formatNumber(monetizationViews))",
                healthScore: min(100, platformHealth + 2),
                trendEmoji: "💎",
                isSpike: false
            )
        ]
    }

    private func setupStrikeSnapshots() {
        var snapshots: [StrikeSnapshot] = []

        let pendingFlags = contentFlags
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)

        for flag in pendingFlags {
            let strikeCount = max(1, min(3, flag.confidence / 35))
            let aiRisk = min(100, max(flag.confidence, strikeQueueCount * 10 + 30))
            snapshots.append(
                StrikeSnapshot(
                    caseId: flag.id,
                    username: flag.creatorName,
                    latestViolation: flag.violationType,
                    strikeCount: strikeCount,
                    aiRisk: aiRisk
                )
            )
        }

        if snapshots.count < 3 {
            let fraudCases = fraudAlerts
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(3 - snapshots.count)

            for alert in fraudCases {
                let digits = alert.amount.filter { $0.isNumber }
                let numericAmount = Int(digits) ?? 0
                let aiRisk = min(100, max(45, numericAmount / 400))
                snapshots.append(
                    StrikeSnapshot(
                        caseId: alert.id,
                        username: "User #\(alert.userId.prefix(6))",
                        latestViolation: alert.description,
                        strikeCount: 2,
                        aiRisk: aiRisk
                    )
                )
            }
        }

        if snapshots.isEmpty {
            snapshots = [
                StrikeSnapshot(
                    caseId: "AUTO-\(UUID().uuidString.prefix(6))",
                    username: "Compliance Monitor",
                    latestViolation: "System clean · no pending cases",
                    strikeCount: 0,
                    aiRisk: 5
                )
            ]
        }

        strikeSnapshots = snapshots
    }

    private func buildCountries(totalUsers: Int) -> [CountryStat] {
        let base = max(1, totalUsers)
        return [
            CountryStat(flag: "🇺🇸", name: "United States", users: Int(Double(base) * 0.38), percent: 38),
            CountryStat(flag: "🇬🇧", name: "United Kingdom", users: Int(Double(base) * 0.12), percent: 12),
            CountryStat(flag: "🇨🇦", name: "Canada", users: Int(Double(base) * 0.09), percent: 9),
            CountryStat(flag: "🇦🇺", name: "Australia", users: Int(Double(base) * 0.07), percent: 7),
            CountryStat(flag: "🇳🇬", name: "Nigeria", users: Int(Double(base) * 0.06), percent: 6),
        ]
    }

    func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
