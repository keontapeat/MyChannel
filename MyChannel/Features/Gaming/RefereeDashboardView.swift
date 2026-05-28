//
//  RefereeDashboardView.swift
//  MyChannel
//
//  Admin Dashboard for Reviewing Disputed Matches
//  Professional referee interface with side-by-side video players
//

import SwiftUI
import AVKit

struct RefereeDashboardView: View {
    @StateObject private var viewModel = RefereeDashboardViewModel()
    @State private var selectedMatch: DisputedMatch?
    @State private var showingReviewSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.Colors.background.ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.disputedMatches.isEmpty {
                    emptyView
                } else {
                    matchListView
                }
            }
            .navigationTitle("Referee Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showingReviewSheet) {
                if let match = selectedMatch {
                    MatchReviewSheet(match: match, viewModel: viewModel)
                }
            }
        }
        .task {
            await viewModel.loadDisputedMatches()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading disputed matches...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: 8) {
                Text("All Clear!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("No disputed matches to review")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Match List View
    
    private var matchListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats header
                statsHeader
                
                // Match list
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.disputedMatches) { match in
                        DisputedMatchCard(match: match)
                            .onTapGesture {
                                selectedMatch = match
                                showingReviewSheet = true
                            }
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Pending",
                value: "\(viewModel.disputedMatches.count)",
                icon: "clock.fill",
                color: .orange
            )
            
            statCard(
                title: "Reviewed Today",
                value: "\(viewModel.reviewedToday)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            statCard(
                title: "Avg Review Time",
                value: "\(viewModel.avgReviewTime)m",
                icon: "timer",
                color: .blue
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.loadDisputedMatches()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
        }
    }
}

// MARK: - Disputed Match Card

struct DisputedMatchCard: View {
    let match: DisputedMatch
    
    private func safeInt(_ value: Double, fallback: Int = 0) -> Int {
        guard value.isFinite else { return fallback }
        return Int(value.rounded())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match #\(match.id.prefix(8))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(match.game)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Urgency badge
                urgencyBadge
            }
            
            // Players
            HStack(spacing: 8) {
                playerChip(name: match.player1Name, score: match.player1Score)
                
                Text("VS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                playerChip(name: match.player2Name, score: match.player2Score)
            }
            
            // Info row
            HStack(spacing: 16) {
                infoItem(icon: "dollarsign.circle.fill", text: "$\(safeInt(match.wagerAmount))")
                infoItem(icon: "brain", text: "\(safeInt(match.aiConfidence * 100))%")
                infoItem(icon: "clock.fill", text: match.timeAgo)
            }
            
            // Review button
            HStack {
                Spacer()
                
                Text("Tap to Review")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(urgencyColor.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private var urgencyBadge: some View {
        Text(match.urgency.rawValue.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(urgencyColor)
            )
    }
    
    private var urgencyColor: Color {
        switch match.urgency {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    private func playerChip(name: String, score: Int) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
            
            Text("\(score)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.Colors.background)
        )
    }
    
    private func infoItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Match Review Sheet

struct MatchReviewSheet: View {
    let match: DisputedMatch
    @ObservedObject var viewModel: RefereeDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedWinnerId: String?
    @State private var reviewNote: String = ""
    @State private var showingPlayer1Video = true
    @State private var isSubmitting = false
    
    private func safeInt(_ value: Double, fallback: Int = 0) -> Int {
        guard value.isFinite else { return fallback }
        return Int(value.rounded())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Match info
                        matchInfoCard
                        
                        // Video comparison
                        videoComparisonSection
                        
                        // AI analysis
                        aiAnalysisCard
                        
                        // Decision section
                        decisionSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Review Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitDecision()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canSubmit ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
    }
    
    // MARK: - Match Info Card
    
    private var matchInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Match Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                infoRow(label: "Match ID", value: match.id.prefix(12).description)
                infoRow(label: "Game", value: match.game)
                infoRow(label: "Wager", value: "$\(safeInt(match.wagerAmount))")
                infoRow(label: "Submitted", value: match.timeAgo)
                infoRow(label: "Reason", value: match.disputeReason)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
    
    // MARK: - Video Comparison
    
    private var videoComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video Proofs")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Player toggle
            HStack(spacing: 0) {
                playerToggleButton(
                    player: match.player1Name,
                    score: match.player1Score,
                    isSelected: showingPlayer1Video,
                    action: { showingPlayer1Video = true }
                )
                
                playerToggleButton(
                    player: match.player2Name,
                    score: match.player2Score,
                    isSelected: !showingPlayer1Video,
                    action: { showingPlayer1Video = false }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.Colors.surface)
            )
            
            // Video player
            videoPlayerCard
        }
    }
    
    private func playerToggleButton(player: String, score: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(player)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                
                Text("Score: \(score)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppTheme.Colors.primary : Color.clear)
            )
        }
    }
    
    private var videoPlayerCard: some View {
        VStack(spacing: 12) {
            // Video player placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text(showingPlayer1Video ? match.player1Name : match.player2Name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // Video controls
            HStack {
                Button(action: {}) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    // MARK: - AI Analysis Card
    
    private var aiAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("AI Analysis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            VStack(spacing: 12) {
                analysisRow(
                    icon: "checkmark.circle.fill",
                    label: "Overall Confidence",
                    value: "\(safeInt(match.aiConfidence * 100))%",
                    color: confidenceColor
                )
                
                analysisRow(
                    icon: "eye.fill",
                    label: "Scoreboard Detected",
                    value: match.scoreboardDetected ? "Yes" : "No",
                    color: match.scoreboardDetected ? .green : .red
                )
                
                analysisRow(
                    icon: "text.magnifyingglass",
                    label: "P1 Extracted Score",
                    value: match.player1ExtractedScore != nil ? "\(match.player1ExtractedScore!)" : "N/A",
                    color: .blue
                )
                
                analysisRow(
                    icon: "text.magnifyingglass",
                    label: "P2 Extracted Score",
                    value: match.player2ExtractedScore != nil ? "\(match.player2ExtractedScore!)" : "N/A",
                    color: .blue
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private func analysisRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    private var confidenceColor: Color {
        if match.aiConfidence >= 0.9 { return .green }
        if match.aiConfidence >= 0.7 { return .orange }
        return .red
    }
    
    // MARK: - Decision Section
    
    private var decisionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Decision")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Winner selection
            VStack(spacing: 12) {
                Text("Select Winner")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 12) {
                    winnerButton(
                        name: match.player1Name,
                        score: match.player1Score,
                        playerId: match.player1Id,
                        isSelected: selectedWinnerId == match.player1Id
                    )
                    
                    winnerButton(
                        name: match.player2Name,
                        score: match.player2Score,
                        playerId: match.player2Id,
                        isSelected: selectedWinnerId == match.player2Id
                    )
                }
            }
            
            // Review note
            VStack(alignment: .leading, spacing: 8) {
                Text("Review Note")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextEditor(text: $reviewNote)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(height: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.Colors.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private func winnerButton(name: String, score: Int, playerId: String, isSelected: Bool) -> some View {
        Button(action: {
            selectedWinnerId = playerId
        }) {
            VStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.primary)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Helpers
    
    private var canSubmit: Bool {
        selectedWinnerId != nil && !reviewNote.isEmpty
    }
    
    private func submitDecision() {
        guard let winnerId = selectedWinnerId else { return }
        
        isSubmitting = true
        
        Task {
            do {
                try await viewModel.approveMatch(
                    matchId: match.id,
                    winnerId: winnerId,
                    note: reviewNote
                )
                
                dismiss()
            } catch {
                print("🚨 Error submitting decision: \(error)")
            }
            
            isSubmitting = false
        }
    }
}

// MARK: - View Model

@MainActor
class RefereeDashboardViewModel: ObservableObject {
    @Published var disputedMatches: [DisputedMatch] = []
    @Published var isLoading = false
    @Published var reviewedToday = 0
    @Published var avgReviewTime = 15 // minutes
    
    private let verificationService = MatchVerificationService.shared
    
    func loadDisputedMatches() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Load from Firestore
        // For now, use sample data
        disputedMatches = DisputedMatch.sampleMatches
        
        print("✅ [RefereeDashboard] Loaded \(disputedMatches.count) disputed matches")
    }
    
    func approveMatch(matchId: String, winnerId: String, note: String) async throws {
        print("✅ [RefereeDashboard] Approving match: \(matchId), winner: \(winnerId)")
        
        try await verificationService.manuallyApproveMatch(
            matchId: matchId,
            winnerId: winnerId,
            refereeId: getCurrentRefereeId(),
            note: note
        )
        
        // Remove from list
        disputedMatches.removeAll { $0.id == matchId }
        reviewedToday += 1
    }
    
    private func getCurrentRefereeId() -> String {
        // TODO: Get from AuthenticationManager
        return "referee-123"
    }
}

// MARK: - Disputed Match Model

struct DisputedMatch: Identifiable {
    let id: String
    let game: String
    let player1Id: String
    let player1Name: String
    let player1Score: Int
    let player1ExtractedScore: Int?
    let player2Id: String
    let player2Name: String
    let player2Score: Int
    let player2ExtractedScore: Int?
    let wagerAmount: Double
    let aiConfidence: Double
    let scoreboardDetected: Bool
    let submittedAt: Date
    let disputeReason: String
    let urgency: MatchUrgency
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: submittedAt, relativeTo: Date())
    }
    
    static let sampleMatches: [DisputedMatch] = [
        DisputedMatch(
            id: "match-001",
            game: "FIFA 24",
            player1Id: "player-1",
            player1Name: "ProGamer123",
            player1Score: 25,
            player1ExtractedScore: 25,
            player2Id: "player-2",
            player2Name: "ElitePlayer99",
            player2Score: 24,
            player2ExtractedScore: 23,
            wagerAmount: 500.0,
            aiConfidence: 0.75,
            scoreboardDetected: true,
            submittedAt: Date().addingTimeInterval(-3600),
            disputeReason: "Score mismatch: AI extracted different scores",
            urgency: .high
        ),
        DisputedMatch(
            id: "match-002",
            game: "Call of Duty",
            player1Id: "player-3",
            player1Name: "Sniper2024",
            player1Score: 50,
            player1ExtractedScore: nil,
            player2Id: "player-4",
            player2Name: "TacticMaster",
            player2Score: 48,
            player2ExtractedScore: 48,
            wagerAmount: 100.0,
            aiConfidence: 0.60,
            scoreboardDetected: false,
            submittedAt: Date().addingTimeInterval(-7200),
            disputeReason: "Low AI confidence: Scoreboard not clearly visible",
            urgency: .medium
        )
    ]
}

enum MatchUrgency: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

