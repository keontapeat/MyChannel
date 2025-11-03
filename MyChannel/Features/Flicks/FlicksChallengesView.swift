//
//  FlicksChallengesView.swift
//  MyChannel
//
//  FLICKS CHALLENGES - Compete for prize money with AI judging
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct FlicksChallengesView: View {
    @StateObject private var viewModel = FlicksChallengesViewModel()
    @State private var showSubmitFlow = false
    @State private var selectedChallenge: FlicksChallenge?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        challengeHero
                        
                        // Active Challenge
                        if let challenge = viewModel.activeChallenge {
                            activeChallengeCard(challenge: challenge)
                        }
                        
                        // Leaderboard
                        leaderboardSection
                        
                        // Your Submissions
                        mySubmissionsSection
                        
                        // Upcoming Challenges
                        upcomingChallengesSection
                        
                        // Past Winners
                        pastWinnersSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Flicks Challenges")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSubmitFlow) {
            if let challenge = selectedChallenge {
                SubmitChallengeSheet(challenge: challenge)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadChallenges()
            }
        }
    }
    
    // MARK: - Hero Section
    private var challengeHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.3, blue: 0.2),
                            Color(red: 0.7, green: 0.1, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text("Challenges")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Compete for REAL prize money 💰")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Judging")
                    featureBadge(icon: "dollarsign.circle.fill", text: "Cash Prizes")
                    featureBadge(icon: "star.fill", text: "Fair Play")
                }
                
                if let challenge = viewModel.activeChallenge {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Ends in \(viewModel.timeRemaining)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
                }
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Active Challenge Card
    private func activeChallengeCard(challenge: FlicksChallenge) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Challenge header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text(challenge.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Text(challenge.description)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Prize Pool
            VStack(spacing: 12) {
                HStack {
                    Text("💰 Total Prize Pool")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                Text("$\(challenge.totalPrize.abbreviated)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                
                if let sponsor = challenge.sponsor {
                    HStack(spacing: 8) {
                        Text("Sponsored by")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text(sponsor.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Requirements
            VStack(alignment: .leading, spacing: 12) {
                Text("Requirements:")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                ForEach(challenge.requirements, id: \.self) { requirement in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        
                        Text(requirement)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            // Stats
            HStack(spacing: 20) {
                ChallengeStatItem(icon: "person.3.fill", value: "\(challenge.submissions)", label: "Entries")
                ChallengeStatItem(icon: "clock.fill", value: viewModel.timeRemaining, label: "Remaining")
                ChallengeStatItem(icon: "eye.fill", value: "2.4M", label: "Views")
            }
            
            // Submit Button
            Button {
                selectedChallenge = challenge
                showSubmitFlow = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                    Text("Submit Your Entry")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.9, green: 0.3, blue: 0.2), Color(red: 0.7, green: 0.1, blue: 0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.4), radius: 12, x: 0, y: 4)
            }
        }
        .padding(24)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Leaderboard
    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text("Live Leaderboard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                NavigationLink(destination: Text("Full Leaderboard")) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.topSubmissions.prefix(10)) { submission in
                    LeaderboardRow(submission: submission)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - My Submissions
    private var mySubmissionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Submissions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            if viewModel.mySubmissions.isEmpty {
                EmptySubmissionsView()
            } else {
                ForEach(viewModel.mySubmissions) { submission in
                    MySubmissionCard(submission: submission)
                }
            }
        }
    }
    
    // MARK: - Upcoming Challenges
    private var upcomingChallengesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Coming Soon")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ForEach(viewModel.upcomingChallenges) { challenge in
                UpcomingChallengeCard(challenge: challenge)
            }
        }
    }
    
    // MARK: - Past Winners
    private var pastWinnersSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Hall of Fame")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(viewModel.pastWinners) { winner in
                PastWinnerCard(winner: winner)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct ChallengeStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LeaderboardRow: View {
    let submission: ChallengeSubmission
    
    var medalColor: Color {
        switch submission.rank {
        case 1: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case 2: return Color(red: 0.7, green: 0.7, blue: 0.7)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.Colors.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Rank
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                if submission.rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(medalColor)
                } else {
                    Text("#\(submission.rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            
            // Thumbnail
            AsyncImage(url: URL(string: submission.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Creator Info
            VStack(alignment: .leading, spacing: 4) {
                Text(submission.creator.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                        Text("\(submission.aiScore)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 11))
                        Text("\(submission.votes)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Prize
            if submission.isWinner {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(submission.prize)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("Prize")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(submission.rank <= 3 ? medalColor.opacity(0.05) : AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(submission.rank <= 3 ? medalColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

struct MySubmissionCard: View {
    let submission: ChallengeSubmission
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: submission.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Rank #\(submission.rank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    if submission.rank <= 50 {
                        Text("Winner!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Score")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("\(submission.aiScore)/100")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Votes")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("\(submission.votes)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Views")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text(submission.views.abbreviated)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                if submission.prize > 0 {
                    Text("Prize: $\(submission.prize)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptySubmissionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No submissions yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Create a Flick and submit it to win prizes!")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct UpcomingChallengeCard: View {
    let challenge: FlicksChallenge
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(challenge.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(challenge.description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 14))
                        Text("$\(challenge.totalPrize.abbreviated)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.green)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                        Text("Starts \(challenge.startsIn)")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(18)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PastWinnerCard: View {
    let winner: ChallengeWinner
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: winner.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                Image(systemName: "crown.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(8)
                , alignment: .topLeading
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(winner.challengeTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: winner.creator.avatarURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    
                    Text(winner.creator.name)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text("Won $\(winner.prize)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Submit Challenge Sheet
struct SubmitChallengeSheet: View {
    let challenge: FlicksChallenge
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Submit your Flick to the challenge")
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                // Challenge selection and submission flow
                Text("Submission flow coming soon")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            .padding(24)
            .background(AppTheme.Colors.background)
            .navigationTitle("Submit to Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FlicksChallengesView()
}
