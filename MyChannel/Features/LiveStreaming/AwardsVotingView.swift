//
//  AwardsVotingView.swift
//  MyChannel
//
//  UI for voting on Streamer Awards
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct AwardsVotingView: View {
    
    @StateObject private var votingService = StreamerAwardsVotingService.shared
    @State private var selectedCategory: AwardCategory?
    @State private var showResults = false
    @State private var searchText = ""
    @State private var showVoteConfirmation = false
    @State private var votedCategoryName = ""
    
    // Award categories (26 total)
    private let categories: [AwardCategory] = [
        // Content Categories
        AwardCategory(id: "streamer-of-year", name: "Streamer of the Year", icon: "crown.fill", color: .yellow),
        AwardCategory(id: "best-newcomer", name: "Best Newcomer", icon: "star.fill", color: .blue),
        AwardCategory(id: "best-gaming", name: "Best Gaming Streamer", icon: "gamecontroller.fill", color: .purple),
        AwardCategory(id: "best-irl", name: "Best IRL Streamer", icon: "camera.fill", color: .orange),
        AwardCategory(id: "best-creative", name: "Best Creative Streamer", icon: "paintbrush.fill", color: .pink),
        AwardCategory(id: "best-music", name: "Best Music Streamer", icon: "music.note", color: .red),
        AwardCategory(id: "best-cooking", name: "Best Cooking Streamer", icon: "flame.fill", color: .orange),
        AwardCategory(id: "best-fitness", name: "Best Fitness Streamer", icon: "figure.run", color: .green),
        AwardCategory(id: "best-educational", name: "Best Educational Content", icon: "book.fill", color: .blue),
        AwardCategory(id: "best-comedy", name: "Best Comedy Streamer", icon: "theatermasks.fill", color: .yellow),
        
        // Community Categories
        AwardCategory(id: "best-community", name: "Best Community", icon: "person.3.fill", color: .cyan),
        AwardCategory(id: "most-wholesome", name: "Most Wholesome", icon: "heart.fill", color: .pink),
        AwardCategory(id: "best-charity", name: "Best Charity Streamer", icon: "gift.fill", color: .green),
        AwardCategory(id: "most-interactive", name: "Most Interactive", icon: "bubble.left.and.bubble.right.fill", color: .blue),
        
        // Performance Categories
        AwardCategory(id: "best-hype", name: "Best Hype Moments", icon: "bolt.fill", color: .yellow),
        AwardCategory(id: "best-clutch", name: "Best Clutch Plays", icon: "target", color: .red),
        AwardCategory(id: "most-creative", name: "Most Creative Content", icon: "lightbulb.fill", color: .orange),
        AwardCategory(id: "best-production", name: "Best Production Quality", icon: "tv.fill", color: .purple),
        
        // Specialty Categories
        AwardCategory(id: "breakout-star", name: "Breakout Star", icon: "star.fill", color: .yellow),
        AwardCategory(id: "best-duo", name: "Best Duo/Team", icon: "person.2.fill", color: .cyan),
        AwardCategory(id: "best-collab", name: "Best Collaboration", icon: "link", color: .blue),
        AwardCategory(id: "most-entertaining", name: "Most Entertaining", icon: "face.smiling.fill", color: .orange),
        
        // Technical Categories
        AwardCategory(id: "best-editor", name: "Best Editor", icon: "scissors", color: .gray),
        AwardCategory(id: "best-mod-team", name: "Best Mod Team", icon: "shield.fill", color: .green),
        
        // Legacy Categories
        AwardCategory(id: "legacy-award", name: "Legacy Award", icon: "trophy.fill", color: Color(red: 1.0, green: 0.84, blue: 0.0)),
        AwardCategory(id: "peoples-choice", name: "People's Choice", icon: "hand.thumbsup.fill", color: .blue)
    ]
    
    private var filteredCategories: [AwardCategory] {
        if searchText.isEmpty {
            return categories
        }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Header
                        votingHeaderView
                        
                        // Search bar
                        searchBarView
                        
                        // Categories grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md),
                            GridItem(.flexible(), spacing: AppTheme.Spacing.md)
                        ], spacing: AppTheme.Spacing.md) {
                            ForEach(filteredCategories) { category in
                                CategoryCardView(
                                    category: category,
                                    hasVoted: votingService.hasVotedInCategory[category.id] ?? false
                                )
                                .onTapGesture {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        
                        // Results button
                        Button(action: { showResults = true }) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                Text("View Live Results")
                                    .font(AppTheme.Typography.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.Colors.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(AppTheme.CornerRadius.lg)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, AppTheme.Spacing.lg)
                    }
                    .padding(.vertical, AppTheme.Spacing.lg)
                }
            }
            .navigationTitle("Vote for Awards")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedCategory) { category in
                CategoryVotingSheet(
                    category: category,
                    onVoteSubmitted: {
                        votedCategoryName = category.name
                        showVoteConfirmation = true
                    }
                )
            }
            .sheet(isPresented: $showResults) {
                VotingResultsView()
            }
            .alert("Vote Submitted! 🎉", isPresented: $showVoteConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your vote for \(votedCategoryName) has been counted!")
            }
            .task {
                #if canImport(FirebaseAuth)
                if let userId = Auth.auth().currentUser?.uid {
                    await votingService.loadUserVotes(userId: userId)
                }
                #endif
            }
        }
    }
    
    // MARK: - Voting Header
    private var votingHeaderView: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Streamer Awards 2025")
                .font(AppTheme.Typography.largeTitle)
                .fontWeight(.bold)
            
            Text(votingService.currentVotingPeriod.displayName)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            // Voting deadline
            if let endDate = votingDeadline {
                Text("Voting ends \(endDate, style: .relative)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Vote count
            Text("\(votingService.userVotes.count)/\(categories.count) categories voted")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.md)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
    
    private var votingDeadline: Date? {
        votingService.currentVotingPeriod.endDate
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            TextField("Search categories...", text: $searchText)
                .font(AppTheme.Typography.body)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .padding(.horizontal, AppTheme.Spacing.md)
    }
}

// MARK: - Category Card View

struct CategoryCardView: View {
    let category: AwardCategory
    let hasVoted: Bool
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: category.icon)
                    .font(.system(size: 28))
                    .foregroundColor(category.color)
                
                if hasVoted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white))
                        .offset(x: 20, y: -20)
                }
            }
            
            Text(category.name)
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .stroke(hasVoted ? Color.green : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Category Voting Sheet

struct CategoryVotingSheet: View {
    let category: AwardCategory
    let onVoteSubmitted: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var votingService = StreamerAwardsVotingService.shared
    @State private var nominees: [User] = []
    @State private var selectedNominee: User?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Category header
                        categoryHeaderView
                        
                        // Nominees list
                        if isLoading {
                            ProgressView()
                                .padding(AppTheme.Spacing.xl)
                        } else {
                            LazyVStack(spacing: AppTheme.Spacing.md) {
                                ForEach(nominees) { nominee in
                                    NomineeRowView(
                                        nominee: nominee,
                                        isSelected: selectedNominee?.id == nominee.id,
                                        hasVoted: votingService.hasVotedInCategory[category.id] == true,
                                        currentVote: votingService.userVotes[category.id]
                                    )
                                    .onTapGesture {
                                        selectedNominee = nominee
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                        }
                        
                        // Vote button
                        if let nominee = selectedNominee {
                            voteButton(for: nominee)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.lg)
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadNominees()
            }
        }
    }
    
    // MARK: - Category Header
    private var categoryHeaderView: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: category.icon)
                    .font(.system(size: 40))
                    .foregroundColor(category.color)
            }
            
            Text("Vote for your favorite")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if votingService.hasVotedInCategory[category.id] == true {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("You've already voted")
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(.green)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(Color.green.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.md)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
    
    // MARK: - Vote Button
    private func voteButton(for nominee: User) -> some View {
        Button(action: { submitVote(for: nominee) }) {
            HStack {
                Image(systemName: votingService.hasVotedInCategory[category.id] == true ? "arrow.triangle.2.circlepath" : "hand.thumbsup.fill")
                Text(votingService.hasVotedInCategory[category.id] == true ? "Change Vote" : "Submit Vote")
                    .font(AppTheme.Typography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.CornerRadius.lg)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .disabled(isLoading)
    }
    
    // MARK: - Load Nominees
    private func loadNominees() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Fetch nominees from backend
        // For now, use sample data
        nominees = User.sampleUsers.prefix(10).map { $0 }
    }
    
    // MARK: - Submit Vote
    private func submitVote(for nominee: User) {
        #if canImport(FirebaseAuth)
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please log in to vote"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                if votingService.hasVotedInCategory[category.id] == true {
                    try await votingService.changeVote(
                        categoryId: category.id,
                        newNomineeUserId: nominee.id,
                        userId: userId
                    )
                } else {
                    try await votingService.submitVote(
                        categoryId: category.id,
                        nomineeUserId: nominee.id,
                        userId: userId
                    )
                }
                
                isLoading = false
                onVoteSubmitted()
                dismiss()
                
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        #endif
    }
}

// MARK: - Nominee Row View

struct NomineeRowView: View {
    let nominee: User
    let isSelected: Bool
    let hasVoted: Bool
    let currentVote: AwardVote?
    
    private var isCurrentVote: Bool {
        currentVote?.nomineeUserId == nominee.id
    }
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Profile image
            AsyncImage(url: URL(string: nominee.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            // Nominee info
            VStack(alignment: .leading, spacing: 4) {
                Text(nominee.displayName)
                    .font(AppTheme.Typography.headline)
                
                Text("@\(nominee.username)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("\(nominee.subscriberCount.formatted()) subscribers")
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Selection indicator
            if isCurrentVote && hasVoted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            } else if isSelected {
                Image(systemName: "circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.primary)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .stroke(
                    isCurrentVote && hasVoted ? Color.green : (isSelected ? AppTheme.Colors.primary : Color.clear),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Award Category Model

struct AwardCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
}

// MARK: - Preview

#Preview("Awards Voting") {
    AwardsVotingView()
}
