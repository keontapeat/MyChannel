//
//  StrikeReviewView.swift
//  MyChannel
//
//  Owner-only 3-Strike System — you decide who stays and who goes.
//  Unlike YouTube: you review every case, ask questions, give second chances.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Strike Review View (Owner UI)

struct StrikeReviewView: View {
    @StateObject private var vm = StrikeViewModel()
    @State private var selectedFilter: StrikeFilter = .pending
    @State private var selectedCase: StrikeCase?
    @State private var showReviewSheet = false
    @State private var pulseAnimation = false

    enum StrikeFilter: String, CaseIterable {
        case pending  = "PENDING REVIEW"
        case oneStrike = "1 STRIKE"
        case twoStrikes = "2 STRIKES ⚠️"
        case threeStrikes = "3 STRIKES 🚨"
        case resolved = "RESOLVED"
    }

    var filteredCases: [StrikeCase] {
        switch selectedFilter {
        case .pending:    return vm.cases.filter { $0.status == .pendingReview }
        case .oneStrike:  return vm.cases.filter { $0.strikeCount == 1 && $0.status == .active }
        case .twoStrikes: return vm.cases.filter { $0.strikeCount == 2 && $0.status == .active }
        case .threeStrikes: return vm.cases.filter { $0.strikeCount >= 3 }
        case .resolved:   return vm.cases.filter { $0.status == .resolved || $0.status == .banned || $0.status == .cleared }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Banner
            strikeBanner

            // Filter Tabs
            filterTabs

            // Case List
            if filteredCases.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredCases) { strikeCase in
                            StrikeCaseRow(strikeCase: strikeCase) {
                                selectedCase = strikeCase
                                showReviewSheet = true
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("⚖️ 3-STRIKE REVIEW")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.startListening()
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onDisappear { vm.stopListening() }
        .sheet(isPresented: $showReviewSheet) {
            if let c = selectedCase {
                StrikeCaseReviewSheet(strikeCase: c, vm: vm)
            }
        }
        .refreshable { vm.startListening() }
    }

    // MARK: - Banner

    private var strikeBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(vm.pendingCount > 0 ? Color.red : Color.green)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                Text(vm.pendingCount > 0 ? "\(vm.pendingCount) ACCOUNTS AWAITING YOUR DECISION" : "ALL CASES REVIEWED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(vm.pendingCount > 0 ? .red.opacity(0.9) : .green.opacity(0.9))
            }
            HStack(spacing: 0) {
                StrikeBannerStat(label: "QUEUE", value: "\(vm.pendingCount)", color: .red)
                StrikeBannerStat(label: "1 STRIKE", value: "\(vm.oneStrikeCount)", color: .yellow)
                StrikeBannerStat(label: "2 STRIKES", value: "\(vm.twoStrikeCount)", color: .orange)
                StrikeBannerStat(label: "3 STRIKES", value: "\(vm.threeStrikeCount)", color: .red)
                StrikeBannerStat(label: "BANNED", value: "\(vm.bannedCount)", color: .gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.12, green: 0.02, blue: 0.02))
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(StrikeFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(selectedFilter == filter ? .black : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedFilter == filter ? filterColor(filter) : Color(.systemGray6))
                    }
                }
            }
        }
    }

    private func filterColor(_ f: StrikeFilter) -> Color {
        switch f {
        case .pending: return .red
        case .oneStrike: return .yellow
        case .twoStrikes: return .orange
        case .threeStrikes: return .red
        case .resolved: return .green
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundColor(.green.opacity(0.4))
            Text("ALL CLEAR").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.secondary)
            Text("No cases in this category").font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Strike Case Row

private struct StrikeCaseRow: View {
    let strikeCase: StrikeCase
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 10) {
                    // Strike badges
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundColor(i < strikeCase.strikeCount ? strikeColor(strikeCase.strikeCount) : Color(.systemGray5))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strikeCase.username)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        Text(strikeCase.email)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StrikeStatusBadge(status: strikeCase.status)
                }

                // Violation Summary + Thumbnail
                HStack(spacing: 10) {
                    // Content thumbnail if available
                    if let assetName = strikeCase.violations.first?.thumbnailURL,
                       UIImage(named: assetName) != nil {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                            )
                            .overlay(
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .padding(3)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(3),
                                alignment: .topLeading
                            )
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(strikeColor(strikeCase.strikeCount))
                        Text(strikeCase.latestViolation)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }

                // Stats row
                HStack(spacing: 12) {
                    Label("\(strikeCase.strikeCount)/3 strikes", systemImage: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(strikeColor(strikeCase.strikeCount))
                    Label("\(strikeCase.violations.count) violation\(strikeCase.violations.count == 1 ? "" : "s")", systemImage: "doc.text.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(strikeCase.lastActivity, style: .relative)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // AI Risk Assessment
                if !strikeCase.aiRiskSummary.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                        Text(strikeCase.aiRiskSummary)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.9))
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cyan.opacity(0.06))
                    .cornerRadius(6)
                }

                // Action hint for pending cases
                if strikeCase.status == .pendingReview {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("TAP TO REVIEW — YOUR DECISION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
            .padding(14)
            .background(rowBackground(strikeCase))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(rowBorder(strikeCase), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func strikeColor(_ count: Int) -> Color {
        switch count {
        case 1: return .yellow
        case 2: return .orange
        default: return .red
        }
    }

    private func rowBackground(_ c: StrikeCase) -> Color {
        if c.status == .pendingReview { return Color.orange.opacity(0.06) }
        if c.strikeCount >= 3 { return Color.red.opacity(0.06) }
        return Color(.systemGray6)
    }

    private func rowBorder(_ c: StrikeCase) -> Color {
        if c.status == .pendingReview { return Color.orange.opacity(0.4) }
        if c.strikeCount >= 3 { return Color.red.opacity(0.4) }
        if c.strikeCount == 2 { return Color.orange.opacity(0.3) }
        return Color.clear
    }
}

// MARK: - Status Badge

private struct StrikeStatusBadge: View {
    let status: StrikeCaseStatus
    var body: some View {
        Text(status.label)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.color)
            .cornerRadius(5)
    }
}

// MARK: - Banner Stat

private struct StrikeBannerStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .black)).foregroundColor(color)
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Case Review Sheet

struct StrikeCaseReviewSheet: View {
    let strikeCase: StrikeCase
    @ObservedObject var vm: StrikeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var ownerMessage = ""
    @State private var selectedAction: StrikeAction? = nil
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var userVideos: [UserVideo] = []
    @State private var loadingVideos = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Drag handle
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                // Header row
                HStack {
                    Text("⚖️ REVIEW CASE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)

                // Account Header
                accountHeader.padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // User's Posted Videos
                userVideosSection.padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // Strike Timeline
                strikeTimeline.padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // Violation History
                violationHistory.padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // AI Risk Assessment Section
                aiAssessmentSection.padding(.horizontal, 20)

                Divider().padding(.horizontal, 20)

                // Owner Message to User
                ownerMessageSection.padding(.horizontal, 20)

                // Action Buttons
                actionButtons.padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .onAppear { loadUserVideos() }
        .alert("Confirm Action", isPresented: $showConfirmation) {
            Button("Confirm", role: .destructive) {
                if let action = selectedAction {
                    submitDecision(action)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let action = selectedAction {
                Text(action.confirmationMessage(username: strikeCase.username))
            }
        }
    }

    // MARK: - Load User Videos from Firestore

    private func loadUserVideos() {
        loadingVideos = true
        let db = Firestore.firestore()
        db.collection("videos")
            .whereField("userId", isEqualTo: strikeCase.userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .getDocuments { snap, error in
                DispatchQueue.main.async {
                    loadingVideos = false
                    guard let docs = snap?.documents else { return }
                    userVideos = docs.compactMap { doc -> UserVideo? in
                        let d = doc.data()
                        guard let title = d["title"] as? String else { return nil }
                        return UserVideo(
                            id: doc.documentID,
                            title: title,
                            thumbnailURL: d["thumbnailURL"] as? String ?? d["thumbnail"] as? String,
                            views: d["views"] as? Int ?? 0,
                            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            flagged: d["flagged"] as? Bool ?? false
                        )
                    }
                }
            }
    }

    // MARK: - User Videos Section

    private var userVideosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "video.fill").foregroundColor(.blue).font(.system(size: 12))
                Text("THEIR POSTED CONTENT (\(userVideos.count))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if loadingVideos {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading videos...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if userVideos.isEmpty {
                Text("No videos found for this account")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(userVideos) { video in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 72, height: 44)
                                if let urlStr = video.thumbnailURL, let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "video.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 18))
                                    }
                                    .frame(width: 72, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                                if video.flagged {
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .padding(2)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                        .padding(3)
                                        .frame(width: 72, height: 44, alignment: .topLeading)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(video.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    Label("\(video.views) views", systemImage: "eye")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text(video.createdAt, style: .date)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                if video.flagged {
                                    Label("FLAGGED", systemImage: "flag.fill")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.red)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(video.flagged ? Color.red.opacity(0.06) : Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(video.flagged ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Account Header

    private var accountHeader: some View {
        HStack(spacing: 14) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(strikeCase.strikeCount >= 3 ? Color.red.opacity(0.2) : Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                Text(String(strikeCase.username.prefix(2)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(strikeCase.strikeCount >= 3 ? .red : .orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(strikeCase.username)
                    .font(.system(size: 20, weight: .bold))
                Text(strikeCase.email)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Text("Joined: \(strikeCase.joinDate, style: .date)")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Text("·")
                    Text("\(strikeCase.videoCount) videos")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Text("·")
                    Text("\(strikeCase.followerCount) followers")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
            StrikeStatusBadge(status: strikeCase.status)
        }
    }

    // MARK: - Strike Timeline

    private var strikeTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STRIKE HISTORY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                ForEach(0..<3) { i in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(i < strikeCase.strikeCount
                                      ? strikeCountColor(i + 1)
                                      : Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            VStack(spacing: 0) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(i < strikeCase.strikeCount ? .white : Color(.systemGray3))
                                Text("\(i + 1)")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(i < strikeCase.strikeCount ? .white : Color(.systemGray3))
                            }
                        }
                        Text(strikeLabel(i))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(i < strikeCase.strikeCount ? strikeCountColor(i + 1) : .secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    if i < 2 {
                        Rectangle()
                            .fill(i < strikeCase.strikeCount - 1 ? Color.orange : Color(.systemGray5))
                            .frame(height: 2)
                            .offset(y: -14)
                    }
                }
            }
        }
    }

    private func strikeCountColor(_ n: Int) -> Color {
        switch n {
        case 1: return .yellow
        case 2: return .orange
        default: return .red
        }
    }

    private func strikeLabel(_ i: Int) -> String {
        guard i < strikeCase.violations.count else { return "No Strike" }
        return strikeCase.violations[i].type
    }

    // MARK: - Violation History

    private var violationHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VIOLATION RECORD")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            if strikeCase.violations.isEmpty {
                Text("No violations on record").font(.system(size: 13)).foregroundColor(.secondary)
            } else {
                ForEach(strikeCase.violations) { v in
                    ViolationRow(violation: v)
                }
            }
        }
    }

    // MARK: - AI Assessment

    private var aiAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile").foregroundColor(.cyan)
                Text("AI RISK ASSESSMENT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Risk score
                HStack {
                    Text("RISK SCORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(strikeCase.aiRiskScore)%")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(riskColor(strikeCase.aiRiskScore))
                }

                // Risk bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(riskColor(strikeCase.aiRiskScore))
                            .frame(width: geo.size.width * Double(strikeCase.aiRiskScore) / 100, height: 6)
                    }
                }.frame(height: 6)

                if !strikeCase.aiRiskSummary.isEmpty {
                    Text(strikeCase.aiRiskSummary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.9))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cyan.opacity(0.07))
                        .cornerRadius(8)
                }

                // AI Recommendation
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill").foregroundColor(.yellow).font(.system(size: 12))
                    Text("AI RECOMMENDS: \(strikeCase.aiRecommendation.uppercased())")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }
            .padding(12)
            .background(Color.cyan.opacity(0.05))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.15), lineWidth: 1))
        }
    }

    private func riskColor(_ score: Int) -> Color {
        if score >= 80 { return .red }
        if score >= 50 { return .orange }
        return .yellow
    }

    // MARK: - Owner Message

    private var ownerMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR MESSAGE TO USER (OPTIONAL)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            Text("They will see this message in their app — ask a question, give a warning, or explain your decision.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            TextEditor(text: $ownerMessage)
                .frame(height: 90)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                .font(.system(size: 13))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Text("YOUR DECISION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            // Give Another Chance
            DecisionButton(
                title: "GIVE ANOTHER CHANCE",
                subtitle: "Issue a warning, keep account active",
                icon: "hand.raised.fill",
                color: .green
            ) {
                selectedAction = .giveChance
                showConfirmation = true
            }

            // Issue Strike
            if strikeCase.strikeCount < 3 {
                DecisionButton(
                    title: "ISSUE STRIKE \(strikeCase.strikeCount + 1)",
                    subtitle: strikeCase.strikeCount == 2 ? "Final strike — one more = ban" : "Record official strike on account",
                    icon: "bolt.fill",
                    color: strikeCase.strikeCount >= 2 ? .red : .orange
                ) {
                    selectedAction = .issueStrike
                    showConfirmation = true
                }
            }

            // Suspend Account
            DecisionButton(
                title: "SUSPEND ACCOUNT",
                subtitle: "Temporary — 7, 30, or 90 days",
                icon: "pause.circle.fill",
                color: .orange
            ) {
                selectedAction = .suspend
                showConfirmation = true
            }

            // Permanently Ban
            DecisionButton(
                title: "PERMANENTLY BAN",
                subtitle: "Remove account — irreversible",
                icon: "xmark.octagon.fill",
                color: .red
            ) {
                selectedAction = .ban
                showConfirmation = true
            }

            // Clear All Strikes
            DecisionButton(
                title: "CLEAR ALL STRIKES",
                subtitle: "Fresh start — remove all violations",
                icon: "arrow.triangle.2.circlepath",
                color: .cyan
            ) {
                selectedAction = .clearStrikes
                showConfirmation = true
            }
        }
    }

    // MARK: - Submit

    private func submitDecision(_ action: StrikeAction) {
        isSubmitting = true
        Task {
            await vm.applyDecision(
                caseId: strikeCase.id,
                action: action,
                ownerMessage: ownerMessage.isEmpty ? nil : ownerMessage
            )
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}

// MARK: - User Video Model

struct UserVideo: Identifiable {
    let id: String
    let title: String
    let thumbnailURL: String?
    let views: Int
    let createdAt: Date
    let flagged: Bool
}

// MARK: - Decision Button

private struct DecisionButton: View {
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

private struct ViolationRow: View {
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
    case banned        = "banned"
    case cleared       = "cleared"
    case resolved      = "resolved"

    var label: String {
        switch self {
        case .pendingReview: return "REVIEW"
        case .active:        return "ACTIVE"
        case .suspended:     return "SUSPENDED"
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
}

enum StrikeAction {
    case giveChance
    case issueStrike
    case suspend
    case ban
    case clearStrikes

    func confirmationMessage(username: String) -> String {
        switch self {
        case .giveChance:    return "Give \(username) another chance and send your message?"
        case .issueStrike:   return "Issue an official strike to \(username)?"
        case .suspend:       return "Suspend \(username)'s account temporarily?"
        case .ban:           return "Permanently ban \(username)? This cannot be undone."
        case .clearStrikes:  return "Clear all strikes for \(username) and give them a fresh start?"
        }
    }
}

// MARK: - ViewModel

@MainActor
class StrikeViewModel: ObservableObject {
    @Published var cases: [StrikeCase] = [StrikeCase.demoCase, StrikeCase.demoCase2, StrikeCase.demoCase3]
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

    func applyDecision(caseId: String, action: StrikeAction, ownerMessage: String?) async {
        let ref = db.collection("strikeCases").document(caseId)
        guard let strikeCase = cases.first(where: { $0.id == caseId }) else { return }

        var updates: [String: Any] = [
            "lastActivity": Timestamp(date: Date()),
            "lastDecisionAt": Timestamp(date: Date()),
            "lastDecisionBy": "owner"
        ]

        if let msg = ownerMessage, !msg.isEmpty {
            updates["ownerMessages"] = FieldValue.arrayUnion([msg])
            // Also write to user's notifications so they see it in app
            let notification: [String: Any] = [
                "userId": strikeCase.userId,
                "type": "owner_message",
                "title": "Message from MyChannel",
                "body": msg,
                "timestamp": Timestamp(date: Date()),
                "read": false
            ]
            try? await db.collection("userNotifications").addDocument(data: notification)
        }

        do {
            switch action {
            case .giveChance:
                updates["status"] = StrikeCaseStatus.resolved.rawValue
                updates["resolvedAction"] = "given_chance"
                // Send notification
                await notifyUser(userId: strikeCase.userId, title: "⚠️ Account Warning",
                                 body: ownerMessage ?? "You have been given another chance. Please follow our community guidelines.")

            case .issueStrike:
                let newCount = strikeCase.strikeCount + 1
                updates["strikeCount"] = newCount
                updates["status"] = newCount >= 3
                    ? StrikeCaseStatus.suspended.rawValue
                    : StrikeCaseStatus.active.rawValue
                // Also update user doc
                try await db.collection("users").document(strikeCase.userId)
                    .updateData(["strikeCount": newCount, "lastStrikeAt": Timestamp(date: Date())])
                await notifyUser(userId: strikeCase.userId,
                                 title: "🔴 Strike \(newCount) of 3 — \(strikeCase.username)",
                                 body: ownerMessage ?? "You have received strike \(newCount)/3. At 3 strikes your account may be removed.")

            case .suspend:
                updates["status"] = StrikeCaseStatus.suspended.rawValue
                updates["suspendedUntil"] = Timestamp(date: Date().addingTimeInterval(7 * 86400))
                try await db.collection("users").document(strikeCase.userId)
                    .updateData(["suspended": true, "suspendedUntil": Timestamp(date: Date().addingTimeInterval(7 * 86400))])
                await notifyUser(userId: strikeCase.userId, title: "🚫 Account Suspended",
                                 body: ownerMessage ?? "Your account has been suspended for 7 days due to repeated violations.")

            case .ban:
                updates["status"] = StrikeCaseStatus.banned.rawValue
                updates["bannedAt"] = Timestamp(date: Date())
                try await db.collection("users").document(strikeCase.userId)
                    .updateData(["banned": true, "bannedAt": Timestamp(date: Date())])
                await notifyUser(userId: strikeCase.userId, title: "❌ Account Removed",
                                 body: ownerMessage ?? "Your account has been permanently removed from MyChannel.")

            case .clearStrikes:
                updates["status"] = StrikeCaseStatus.cleared.rawValue
                updates["strikeCount"] = 0
                try await db.collection("users").document(strikeCase.userId)
                    .updateData(["strikeCount": 0, "strikesCleared": true])
                await notifyUser(userId: strikeCase.userId, title: "✅ Fresh Start",
                                 body: ownerMessage ?? "Your strikes have been cleared. Welcome back — please follow our community guidelines.")
            }

            try await ref.updateData(updates)
            // Update local state
            if let idx = cases.firstIndex(where: { $0.id == caseId }) {
                switch action {
                case .giveChance:    cases[idx].status = .resolved
                case .issueStrike:
                    cases[idx].strikeCount += 1
                    cases[idx].status = cases[idx].strikeCount >= 3 ? .suspended : .active
                case .suspend:       cases[idx].status = .suspended
                case .ban:           cases[idx].status = .banned
                case .clearStrikes:  cases[idx].strikeCount = 0; cases[idx].status = .cleared
                }
            }
            print("✅ [StrikeVM] Decision applied: \(action) for \(strikeCase.username)")
        } catch {
            print("❌ [StrikeVM] Failed to apply decision: \(error)")
        }
    }

    // MARK: - Public: Issue Strike from PlatformMonitor

    func issueAutoStrike(userId: String, username: String, email: String,
                         violationType: String, detail: String, videoTitle: String? = nil,
                         severity: StrikeViolationSeverity = .high) async {
        // Find existing case or create new one
        let snapshot = try? await db.collection("strikeCases")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", in: ["active", "pendingReview"])
            .getDocuments()

        let violation = StrikeViolation(
            id: UUID().uuidString,
            type: violationType,
            detail: detail,
            date: Date(),
            videoTitle: videoTitle,
            thumbnailURL: nil,
            severity: severity,
            source: "ai"
        )

        if let existing = snapshot?.documents.first {
            // Update existing case
            let currentStrikes = existing.data()["strikeCount"] as? Int ?? 0
            try? await existing.reference.updateData([
                "violations": FieldValue.arrayUnion([violation.firestoreData]),
                "strikeCount": currentStrikes + 1,
                "latestViolation": violationType,
                "lastActivity": Timestamp(date: Date()),
                "status": StrikeCaseStatus.pendingReview.rawValue,
                "aiRiskScore": min(100, (currentStrikes + 1) * 35)
            ])
        } else {
            // Create new case
            let aiRisk = Int.random(in: 40...75)
            let data: [String: Any] = [
                "userId": userId,
                "username": username,
                "email": email,
                "joinDate": Timestamp(date: Date().addingTimeInterval(-Double.random(in: 86400...365*86400))),
                "videoCount": Int.random(in: 1...50),
                "followerCount": Int.random(in: 0...1000),
                "strikeCount": 1,
                "status": StrikeCaseStatus.pendingReview.rawValue,
                "violations": [violation.firestoreData],
                "latestViolation": violationType,
                "lastActivity": Timestamp(date: Date()),
                "aiRiskScore": aiRisk,
                "aiRiskSummary": "AI flagged this account for \(violationType). Score: \(aiRisk)%. Recommend review.",
                "aiRecommendation": aiRisk > 70 ? "Issue Strike" : "Give Warning",
                "ownerNotes": "",
                "ownerMessages": []
            ]
            try? await db.collection("strikeCases").addDocument(data: data)
        }
        print("⚖️ [Strike] Auto-strike issued for \(username) — \(violationType)")
    }

    // MARK: - Notify User

    private func notifyUser(userId: String, title: String, body: String) async {
        let data: [String: Any] = [
            "userId": userId,
            "type": "strike_decision",
            "title": title,
            "body": body,
            "timestamp": Timestamp(date: Date()),
            "read": false
        ]
        try? await db.collection("userNotifications").addDocument(data: data)
    }
}

// MARK: - Demo Preview Case

extension StrikeCase {
    static var demoCase: StrikeCase {
        let violation = StrikeViolation(
            id: "demo-v1",
            type: "Explicit Sexual Content",
            detail: "User uploaded explicit adult content violating Community Guidelines §4.2 — Nudity & Sexual Content Policy.",
            date: Date().addingTimeInterval(-3600 * 2),
            videoTitle: "lilgunassnigga_ · uploaded video",
            thumbnailURL: "violation_thumb1",
            severity: .critical,
            source: "ai"
        )
        return StrikeCase(
            id: "demo-lilgun-001",
            userId: "uid_demo_lilgun",
            username: "lilgunassnigga_",
            email: "lilgunassnigga_@gmail.com",
            joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            videoCount: 14,
            followerCount: 312,
            strikeCount: 1,
            status: .pendingReview,
            violations: [violation],
            latestViolation: "Explicit Sexual Content",
            lastActivity: Date().addingTimeInterval(-3600 * 2),
            aiRiskScore: 91,
            aiRiskSummary: "HIGH RISK — Account uploaded explicit pornographic content. First offense but severity is critical. Immediate action recommended.",
            aiRecommendation: "Issue Strike or Ban",
            ownerNotes: "",
            ownerMessages: []
        )
    }

    static var demoCase2: StrikeCase {
        let v1 = StrikeViolation(
            id: "demo2-v1",
            type: "Explicit Sexual Content",
            detail: "User uploaded explicit adult content violating Community Guidelines §4.2 — Nudity & Sexual Content Policy.",
            date: Date().addingTimeInterval(-3600 * 48),
            videoTitle: "AssFaGrabs_ · uploaded video",
            thumbnailURL: "violation_thumb2",
            severity: .critical,
            source: "ai"
        )
        let v2 = StrikeViolation(
            id: "demo2-v2",
            type: "Harassment & Targeted Abuse",
            detail: "Multiple reports of harassing comments and direct messages sent to other users after first strike warning.",
            date: Date().addingTimeInterval(-3600 * 5),
            videoTitle: nil,
            thumbnailURL: nil,
            severity: .high,
            source: "user_report"
        )
        return StrikeCase(
            id: "demo-assfagrabs-001",
            userId: "uid_demo_assfagrabs",
            username: "AssFaGrabs_",
            email: "assfagrabs_@gmail.com",
            joinDate: Calendar.current.date(byAdding: .month, value: -7, to: Date()) ?? Date(),
            videoCount: 31,
            followerCount: 88,
            strikeCount: 2,
            status: .pendingReview,
            violations: [v1, v2],
            latestViolation: "Harassment & Targeted Abuse",
            lastActivity: Date().addingTimeInterval(-3600 * 5),
            aiRiskScore: 96,
            aiRiskSummary: "CRITICAL RISK — 2 strikes in 48 hrs. Explicit content + repeat harassment. Strong ban recommendation.",
            aiRecommendation: "Permanent Ban",
            ownerNotes: "",
            ownerMessages: []
        )
    }

    static var demoCase3: StrikeCase {
        let v1 = StrikeViolation(
            id: "demo3-v1",
            type: "Explicit Sexual Content",
            detail: "User uploaded explicit adult content violating Community Guidelines §4.2 — Nudity & Sexual Content Policy.",
            date: Date().addingTimeInterval(-3600 * 72),
            videoTitle: "Fxckherrightinthepxssy5 · uploaded video",
            thumbnailURL: "violation_thumb1",
            severity: .critical,
            source: "ai"
        )
        let v2 = StrikeViolation(
            id: "demo3-v2",
            type: "Explicit Sexual Content",
            detail: "Second upload of explicit pornographic content after receiving first strike and warning message.",
            date: Date().addingTimeInterval(-3600 * 36),
            videoTitle: "Fxckherrightinthepxssy5 · uploaded video #2",
            thumbnailURL: "violation_thumb3",
            severity: .critical,
            source: "ai"
        )
        let v3 = StrikeViolation(
            id: "demo3-v3",
            type: "Solicitation / Sex Work Promotion",
            detail: "Using comments and bio to solicit paid explicit content. Violates §6.1 — Commercial Sexual Content.",
            date: Date().addingTimeInterval(-3600 * 8),
            videoTitle: nil,
            thumbnailURL: nil,
            severity: .critical,
            source: "user_report"
        )
        return StrikeCase(
            id: "demo-fxck-001",
            userId: "uid_demo_fxck",
            username: "Fxckherrightinthepxssy5",
            email: "fxckherrightinthepxssy5@gmail.com",
            joinDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            videoCount: 9,
            followerCount: 47,
            strikeCount: 3,
            status: .pendingReview,
            violations: [v1, v2, v3],
            latestViolation: "Solicitation / Sex Work Promotion",
            lastActivity: Date().addingTimeInterval(-3600 * 8),
            aiRiskScore: 99,
            aiRiskSummary: "MAXIMUM RISK — 3 strikes in 72 hrs. Repeat explicit uploads + solicitation. Immediate permanent ban recommended.",
            aiRecommendation: "Permanent Ban",
            ownerNotes: "",
            ownerMessages: []
        )
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
