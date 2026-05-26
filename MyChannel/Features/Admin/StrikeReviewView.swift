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
        .sheet(item: $selectedCase) { c in
            StrikeCaseReviewSheet(strikeCase: c, vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                    // Real user profile picture
                    ZStack {
                        if let urlStr = strikeCase.profileImageURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                default:
                                    Circle().fill(Color(.systemGray4))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(String(strikeCase.username.prefix(2)).uppercased())
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.secondary)
                                        )
                                }
                            }
                        } else {
                            Circle().fill(Color(.systemGray4))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(strikeCase.username.prefix(2)).uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.secondary)
                                )
                        }
                        // Strike count badge
                        if strikeCase.strikeCount > 0 {
                            ZStack {
                                Circle().fill(strikeColor(strikeCase.strikeCount))
                                    .frame(width: 16, height: 16)
                                Text("\(strikeCase.strikeCount)")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 14, y: 14)
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

                // Violation Summary
                HStack(spacing: 10) {
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
    @State private var suspendDays: Int = 7
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var userVideos: [UserVideo] = []
    @State private var loadingVideos = true
    @State private var profileImageURL: URL? = nil
    @State private var reporterCount: Int = 0

    private var initialProfileURL: URL? {
        if let s = strikeCase.profileImageURL { return URL(string: s) }
        return nil
    }
    @State private var flaggedContentImages: [FlaggedContent] = []
    @State private var loadingFlagged = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {

                    // Risk Banner at top
                    riskBanner

                    // Account Header with profile pic
                    accountHeader.padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // Flagged Content Evidence — the actual images/videos they uploaded
                    flaggedContentSection.padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // Strike Timeline
                    strikeTimeline.padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // Violation History
                    violationHistory.padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // User's Other Posted Videos
                    userVideosSection.padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // AI Risk Assessment Section
                    aiAssessmentSection.padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // Owner Message to User
                    ownerMessageSection.padding(.horizontal, 20)

                    // Action Buttons
                    actionButtons.padding(.horizontal, 20)

                    Spacer(minLength: 60)
                }
                .padding(.top, 10)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Review Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .onAppear {
                profileImageURL = initialProfileURL
                loadUserVideos()
                loadProfileImage()
                loadFlaggedContent()
                loadReporterCount()
            }
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
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().scaleEffect(1.4)
                            Text("Applying decision...")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    // MARK: - Load Profile Image from Firestore

    private func loadProfileImage() {
        let db = Firestore.firestore()
        db.collection("users").document(strikeCase.userId).getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            let urlStr = data["profileImageURL"] as? String
                ?? data["photoURL"] as? String
                ?? data["avatarURL"] as? String
            if let urlStr, let url = URL(string: urlStr) {
                Task { @MainActor in profileImageURL = url }
            }
        }
    }

    // MARK: - Load Flagged Content from Firestore

    private func loadFlaggedContent() {
        loadingFlagged = true
        let db = Firestore.firestore()
        db.collection("flaggedContent")
            .whereField("userId", isEqualTo: strikeCase.userId)
            .order(by: "flaggedAt", descending: true)
            .limit(to: 10)
            .getDocuments { snap, _ in
                Task { @MainActor in
                    loadingFlagged = false
                    guard let docs = snap?.documents else { return }
                    flaggedContentImages = docs.compactMap { doc -> FlaggedContent? in
                        let d = doc.data()
                        return FlaggedContent(
                            id: doc.documentID,
                            imageURL: d["imageURL"] as? String ?? d["thumbnailURL"] as? String ?? d["mediaURL"] as? String,
                            videoURL: d["videoURL"] as? String,
                            title: d["title"] as? String ?? "Flagged content",
                            reason: d["reason"] as? String ?? d["violationType"] as? String ?? "Policy violation",
                            flaggedAt: (d["flaggedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            reportCount: d["reportCount"] as? Int ?? 1
                        )
                    }
                    // If no flaggedContent collection docs, try pulling from violation thumbnails
                    if flaggedContentImages.isEmpty {
                        flaggedContentImages = strikeCase.violations.compactMap { v -> FlaggedContent? in
                            guard v.thumbnailURL != nil || v.videoTitle != nil else { return nil }
                            return FlaggedContent(
                                id: v.id,
                                imageURL: v.thumbnailURL,
                                videoURL: nil,
                                title: v.videoTitle ?? v.type,
                                reason: v.type,
                                flaggedAt: v.date,
                                reportCount: 1
                            )
                        }
                    }
                }
            }
    }

    // MARK: - Load Reporter Count

    private func loadReporterCount() {
        let db = Firestore.firestore()
        db.collection("reports")
            .whereField("reportedUserId", isEqualTo: strikeCase.userId)
            .getDocuments { snap, _ in
                Task { @MainActor in
                    reporterCount = snap?.documents.count ?? 0
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
                Task { @MainActor in
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

    // MARK: - Risk Banner

    private var riskBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: riskIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(riskLabel)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("\(strikeCase.strikeCount)/3 STRIKES")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
            }
            HStack(spacing: 12) {
                Label("\(strikeCase.violations.count) violation\(strikeCase.violations.count == 1 ? "" : "s")", systemImage: "doc.text.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                if reporterCount > 0 {
                    Label("\(reporterCount) report\(reporterCount == 1 ? "" : "s")", systemImage: "person.2.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Text(strikeCase.lastActivity, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: riskGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(0)
    }

    private var riskIcon: String {
        if strikeCase.aiRiskScore >= 80 { return "exclamationmark.octagon.fill" }
        if strikeCase.aiRiskScore >= 50 { return "exclamationmark.triangle.fill" }
        return "info.circle.fill"
    }

    private var riskLabel: String {
        if strikeCase.aiRiskScore >= 90 { return "MAXIMUM RISK" }
        if strikeCase.aiRiskScore >= 80 { return "CRITICAL RISK" }
        if strikeCase.aiRiskScore >= 60 { return "HIGH RISK" }
        if strikeCase.aiRiskScore >= 40 { return "MODERATE RISK" }
        return "LOW RISK"
    }

    private var riskGradient: [Color] {
        if strikeCase.aiRiskScore >= 80 { return [Color.red, Color.red.opacity(0.8)] }
        if strikeCase.aiRiskScore >= 50 { return [Color.orange, Color.orange.opacity(0.8)] }
        return [Color.yellow.opacity(0.8), Color.yellow.opacity(0.6)]
    }

    // MARK: - Account Header

    private var accountHeader: some View {
        HStack(spacing: 14) {
            // Profile Image from Firestore
            ZStack {
                Circle()
                    .fill(strikeCase.strikeCount >= 3 ? Color.red.opacity(0.2) : Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                if let url = profileImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        case .failure:
                            avatarFallback
                        default:
                            ProgressView().frame(width: 60, height: 60)
                        }
                    }
                } else {
                    avatarFallback
                }
                // Strike badge overlay
                if strikeCase.strikeCount > 0 {
                    ZStack {
                        Circle().fill(strikeCase.strikeCount >= 3 ? Color.red : Color.orange)
                            .frame(width: 22, height: 22)
                        Text("\(strikeCase.strikeCount)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                    }
                    .offset(x: 22, y: 22)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(strikeCase.username)
                    .font(.system(size: 18, weight: .bold))
                Text(strikeCase.email)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label("\(strikeCase.videoCount)", systemImage: "video.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("|").foregroundColor(.secondary).font(.system(size: 10))
                    Label("\(strikeCase.followerCount)", systemImage: "person.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("|").foregroundColor(.secondary).font(.system(size: 10))
                    Label("Joined \(strikeCase.joinDate, style: .date)", systemImage: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            StrikeStatusBadge(status: strikeCase.status)
        }
    }

    private var avatarFallback: some View {
        Text(String(strikeCase.username.prefix(2)).uppercased())
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(strikeCase.strikeCount >= 3 ? .red : .orange)
            .frame(width: 60, height: 60)
    }

    // MARK: - Flagged Content Evidence

    private var flaggedContentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red).font(.system(size: 12))
                Text("FLAGGED CONTENT EVIDENCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if loadingFlagged {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading evidence...")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if flaggedContentImages.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.secondary)
                    Text("No flagged media on record — violations may be text/behavioral")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(flaggedContentImages) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            // Evidence image/thumbnail
                            if let urlStr = item.imageURL, let url = URL(string: urlStr) {
                                ZStack(alignment: .topLeading) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 180)
                                                .clipped()
                                                .cornerRadius(10)
                                        case .failure:
                                            evidencePlaceholder
                                        default:
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 180)
                                                .overlay(ProgressView())
                                        }
                                    }
                                    // Violation badge
                                    Text("VIOLATION")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                        .padding(8)
                                }
                            } else {
                                evidencePlaceholder
                            }

                            // Evidence details
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    Label(item.reason, systemImage: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.red)
                                    Spacer()
                                    if item.reportCount > 1 {
                                        Label("\(item.reportCount) reports", systemImage: "flag.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                }
                                Text(item.flaggedAt, style: .relative)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.04))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }

    private var evidencePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.systemGray5))
            .frame(height: 120)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Content removed or unavailable")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            )
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
                VStack(spacing: 8) {
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

    // MARK: - Strike Timeline

    private var strikeTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STRIKE HISTORY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
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
                            .frame(width: 80)
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
            HStack {
                Image(systemName: "doc.text.fill").foregroundColor(.orange).font(.system(size: 12))
                Text("VIOLATION RECORD (\(strikeCase.violations.count))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

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
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(riskColor(strikeCase.aiRiskScore))
                }

                // Risk bar
                ProgressView(value: Double(strikeCase.aiRiskScore), total: 100)
                    .tint(riskColor(strikeCase.aiRiskScore))
                    .scaleEffect(y: 1.5)

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
                    Image(systemName: "lightbulb.fill").foregroundColor(.yellow).font(.system(size: 14))
                    Text("AI RECOMMENDS:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(strikeCase.aiRecommendation.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(8)
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
            HStack {
                Image(systemName: "message.fill").foregroundColor(.blue).font(.system(size: 12))
                Text("YOUR MESSAGE TO USER (OPTIONAL)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text("They will see this in their app — ask a question, give a warning, or explain your decision.")
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
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "gavel.fill").foregroundColor(.primary).font(.system(size: 12))
                Text("YOUR DECISION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
            VStack(spacing: 6) {
                DecisionButton(
                    title: "SUSPEND ACCOUNT",
                    subtitle: "\(suspendDays)-day suspension",
                    icon: "pause.circle.fill",
                    color: .orange
                ) {
                    selectedAction = .suspend
                    showConfirmation = true
                }
                Picker("Suspend duration", selection: $suspendDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)
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
                ownerMessage: ownerMessage.isEmpty ? nil : ownerMessage,
                suspendDays: suspendDays
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

// MARK: - Flagged Content Model

struct FlaggedContent: Identifiable {
    let id: String
    let imageURL: String?
    let videoURL: String?
    let title: String
    let reason: String
    let flaggedAt: Date
    let reportCount: Int
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
    var profileImageURL: String?
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

    func applyDecision(caseId: String, action: StrikeAction, ownerMessage: String?, suspendDays: Int = 7) async {
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
                let suspendInterval = Double(suspendDays) * 86400
                let suspendUntilDate = Date().addingTimeInterval(suspendInterval)
                updates["status"] = StrikeCaseStatus.suspended.rawValue
                updates["suspendedUntil"] = Timestamp(date: suspendUntilDate)
                updates["suspendDays"] = suspendDays
                try await db.collection("users").document(strikeCase.userId)
                    .updateData(["suspended": true, "suspendedUntil": Timestamp(date: suspendUntilDate)])
                await notifyUser(userId: strikeCase.userId, title: "🚫 Account Suspended",
                                 body: ownerMessage ?? "Your account has been suspended for \(suspendDays) days due to repeated violations.")

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
            // Fetch real user data from Firestore
            let userSnap = try? await db.collection("users").document(userId).getDocument()
            let userData = userSnap?.data() ?? [:]
            let profileImageURL = userData["profileImageURL"] as? String
                ?? userData["photoURL"] as? String
                ?? userData["avatarURL"] as? String
            let realJoinDate = (userData["createdAt"] as? Timestamp)?.dateValue()
                ?? (userData["joinDate"] as? Timestamp)?.dateValue()
                ?? Date()
            let realVideoCount = userData["videoCount"] as? Int ?? 0
            let realFollowerCount = userData["subscriberCount"] as? Int
                ?? userData["followerCount"] as? Int ?? 0
            let realEmail = email.isEmpty
                ? (userData["email"] as? String ?? email)
                : email

            // Create new case with real user data
            let aiRisk = 50
            var data: [String: Any] = [
                "userId": userId,
                "username": username,
                "email": realEmail,
                "joinDate": Timestamp(date: realJoinDate),
                "videoCount": realVideoCount,
                "followerCount": realFollowerCount,
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
            if let pic = profileImageURL { data["profileImageURL"] = pic }
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
