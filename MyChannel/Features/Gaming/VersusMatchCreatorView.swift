//
//  VersusMatchCreatorView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  💰 CREATE VS MATCH - Challenge anyone for money! 🔥
//

import SwiftUI

struct VersusMatchCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var matchService = VersusMatchService.shared
    
    @State private var selectedOpponent: User?
    @State private var wagerAmount: String = ""
    @State private var selectedCategory: VersusMatch.Category = .views
    @State private var selectedMatchType: VersusMatch.MatchType = .headToHead
    @State private var matchDuration: Double = 3600 // 1 hour
    @State private var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var customRules: String = ""
    
    @State private var isCreating = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingOpponentPicker = false
    @State private var showingComplianceGate = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Opponent Selection
                    opponentSection
                    
                    // Wager Amount
                    wagerSection
                    
                    // Match Type
                    matchTypeSection
                    
                    // Category
                    categorySection
                    
                    // Duration
                    durationSection
                    
                    // Schedule
                    scheduleSection
                    
                    // Custom Rules
                    rulesSection
                    
                    // Summary
                    summarySection
                    
                    // Create Button
                    createButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Create VS Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Match Created!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your challenge has been sent!")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingOpponentPicker) {
                OpponentPickerView(selectedOpponent: $selectedOpponent)
            }
            .sheet(isPresented: $showingComplianceGate) {
                if let userId = AuthenticationManager.shared.currentUser?.id,
                   let wager = Double(wagerAmount) {
                    VSMatchComplianceSheet(userId: userId, wagerAmount: wager) {
                        // User cleared the gate — proceed straight to creating the match.
                        performCreateMatch()
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Challenge a Creator")
                .font(.system(size: 24, weight: .bold))
            
            Text("Put your money where your mouth is!")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Opponent Selection
    
    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenge Who?")
                .font(.system(size: 18, weight: .bold))
            
            Button {
                HapticManager.shared.impact(style: .light)
                showingOpponentPicker = true
            } label: {
                HStack {
                    if let opponent = selectedOpponent {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opponent.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("@\(opponent.username)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                        
                        Text("Select Opponent")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Wager
    
    private var wagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wager Amount")
                .font(.system(size: 18, weight: .bold))
            
            HStack {
                Text("$")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                TextField("0.00", text: $wagerAmount)
                    .font(.system(size: 24, weight: .bold))
                    .keyboardType(.decimalPad)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)
            
            // Quick amounts
            HStack(spacing: 12) {
                ForEach([10, 25, 50, 100, 500], id: \.self) { amount in
                    Button {
                        wagerAmount = "\(amount)"
                    } label: {
                        Text("$\(amount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(wagerAmount == "\(amount)" ? .white : AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(wagerAmount == "\(amount)" ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .cornerRadius(20)
                    }
                }
            }
            
            Text("Min: $1 • Max: $100,000")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Match Type
    
    private var matchTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Type")
                .font(.system(size: 18, weight: .bold))
            
            ForEach(VersusMatch.MatchType.allCases, id: \.rawValue) { type in
                Button {
                    selectedMatchType = type
                } label: {
                    HStack {
                        Image(systemName: selectedMatchType == type ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedMatchType == type ? AppTheme.Colors.primary : .gray)
                        
                        Text(type.rawValue)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Category
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Competition Category")
                .font(.system(size: 18, weight: .bold))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(VersusMatch.Category.allCases, id: \.rawValue) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 8) {
                            Text(categoryIcon(category))
                                .font(.system(size: 28))
                            
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedCategory == category ?
                            AppTheme.Colors.primary.opacity(0.2) :
                            AppTheme.Colors.surface
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedCategory == category ?
                                    AppTheme.Colors.primary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Duration
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Duration")
                .font(.system(size: 18, weight: .bold))
            
            VStack(spacing: 8) {
                Slider(value: $matchDuration, in: 1800...14400, step: 1800) // 30 min to 4 hours
                
                Text(formatDuration(matchDuration))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Schedule
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When?")
                .font(.system(size: 18, weight: .bold))
            
            DatePicker("Start Time", selection: $scheduledDate, in: Date()...)
                .datePickerStyle(.compact)
                .padding(16)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Rules
    
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Rules (Optional)")
                .font(.system(size: 18, weight: .bold))
            
            TextEditor(text: $customRules)
                .frame(height: 100)
                .padding(12)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Summary
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Match Summary")
                .font(.system(size: 18, weight: .bold))
            
            VStack(spacing: 12) {
                MatchSummaryRow(label: "Pot Size", value: potSize)
                MatchSummaryRow(label: "Winner Gets", value: winnerGets)
                MatchSummaryRow(label: "Platform Fee", value: platformFee)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.1), .red.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
    }
    
    // Money previews computed in integer cents (rounded) via MoneyMath so they
    // match the server's actual settlement math — no floating-point drift.
    private var grossCents: Int {
        guard let wager = Double(wagerAmount) else { return 0 }
        return MoneyMath.cents(fromDollars: wager) * 2
    }
    
    private var potSize: String {
        "$\(MoneyMath.dollars(fromCents: grossCents).formatted(.number.precision(.fractionLength(0...2))))"
    }
    
    private var winnerGets: String {
        let payout = MoneyMath.dollars(fromCents: MoneyMath.winnerPayoutCents(grossCents: grossCents))
        return "$\(payout.formatted(.number.precision(.fractionLength(0...2))))"
    }
    
    private var platformFee: String {
        let fee = MoneyMath.dollars(fromCents: MoneyMath.platformFeeCents(grossCents: grossCents))
        return "$\(fee.formatted(.number.precision(.fractionLength(0...2)))) (10%)"
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        Button {
            createMatch()
        } label: {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "flame.fill")
                    Text("Send Challenge")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .disabled(isCreating || !canCreate)
        .opacity(canCreate ? 1.0 : 0.5)
    }
    
    private var canCreate: Bool {
        selectedOpponent != nil &&
        !wagerAmount.isEmpty &&
        WagerPolicy.isValidWagerAmount(Double(wagerAmount) ?? 0)
    }
    
    // MARK: - Actions
    
    /// Entry point for the "Send Challenge" button. Runs a compliance pre-flight
    /// so a not-yet-eligible user is routed to the onboarding gate instead of
    /// hitting a raw error. If already cleared, creates the match directly.
    private func createMatch() {
        guard selectedOpponent != nil,
              let wager = Double(wagerAmount) else { return }

        guard let challengerId = AuthenticationManager.shared.currentUser?.id else {
            errorMessage = MatchError.userNotLoggedIn.localizedDescription
            showingError = true
            return
        }

        isCreating = true

        Task {
            do {
                // 🔒 Pre-flight the same checks the service enforces. On any
                // compliance failure, open the gate so the user can resolve the
                // self-serviceable items (age / terms) instead of seeing an error.
                _ = try await VSMatchComplianceService.shared.canUserWager(
                    userId: challengerId,
                    amount: wager
                )
            } catch is ComplianceError {
                isCreating = false
                showingComplianceGate = true
                return
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                isCreating = false
                return
            }

            // Already eligible — proceed.
            performCreateMatch()
        }
    }

    /// Actually creates the match. Called either directly (already eligible) or
    /// from the compliance gate's completion handler once the user has cleared.
    private func performCreateMatch() {
        guard let opponent = selectedOpponent,
              let wager = Double(wagerAmount),
              let challengerId = AuthenticationManager.shared.currentUser?.id else { return }

        isCreating = true

        Task {
            do {
                let rules = VersusMatch.MatchRules(
                    duration: matchDuration,
                    category: selectedCategory,
                    winCondition: .mostViews,
                    customRules: customRules.isEmpty ? nil : [customRules]
                )

                _ = try await matchService.createMatch(
                    challengerId: challengerId,
                    opponentId: opponent.id,
                    matchType: selectedMatchType,
                    wagerAmount: wager,
                    category: selectedCategory,
                    rules: rules,
                    scheduledDate: scheduledDate
                )

                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isCreating = false
        }
    }
    
    // MARK: - Helpers
    
    private func categoryIcon(_ category: VersusMatch.Category) -> String {
        switch category {
        case .gaming: return "🎮"
        case .views: return "👁️"
        case .likes: return "❤️"
        case .comments: return "💬"
        case .subscribers: return "👥"
        case .donations: return "💰"
        case .creative: return "🎨"
        case .cooking: return "🍳"
        case .music: return "🎵"
        case .dance: return "💃"
        case .sports: return "⚽"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}

struct MatchSummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Opponent Picker

/// Lets the challenger pick who to bet against. Loads real creators from
/// Firestore (falls back to sample users in debug / when offline) and supports
/// quick search by name or @username.
struct OpponentPickerView: View {
    @Binding var selectedOpponent: User?
    @Environment(\.dismiss) private var dismiss
    
    @State private var allUsers: [User] = []
    @State private var searchText: String = ""
    @State private var isLoading = true
    @State private var loadError: String?
    
    private var currentUserId: String? {
        AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id
    }
    
    private var filteredUsers: [User] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return allUsers }
        let q = searchText.lowercased()
        return allUsers.filter {
            $0.displayName.lowercased().contains(q) || $0.username.lowercased().contains(q)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Finding creators…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredUsers.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredUsers) { user in
                            Button {
                                HapticManager.shared.impact(style: .light)
                                selectedOpponent = user
                                dismiss()
                            } label: {
                                opponentRow(user)
                            }
                            .listRowBackground(AppTheme.Colors.surface)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppTheme.Colors.background)
            .searchable(text: $searchText, prompt: "Search creators")
            .navigationTitle("Choose Opponent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadUsers() }
        }
    }
    
    private func opponentRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if selectedOpponent?.id == user.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(loadError ?? "No creators found")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let users = try await UserFirestoreService.shared.fetchTopCreators(
                excludingUserId: currentUserId
            )
            if users.isEmpty {
                allUsers = User.sampleUsers.filter { $0.id != currentUserId }
            } else {
                allUsers = users
            }
        } catch {
            loadError = "Couldn't load creators. Pull to retry."
            allUsers = User.sampleUsers.filter { $0.id != currentUserId }
        }
    }
}

#Preview {
    VersusMatchCreatorView()
}

