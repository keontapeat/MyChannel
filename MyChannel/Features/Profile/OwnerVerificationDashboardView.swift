//
//  OwnerVerificationDashboardView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/21/25.
//

import SwiftUI

struct OwnerVerificationDashboardView: View {
    @StateObject private var viewModel = OwnerVerificationDashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                summaryCards
                eligibleSection
                verifiedSection
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VerificationSummaryCard(
                title: "Verified",
                value: "\(viewModel.verifiedUsers.count)",
                subtitle: "Blue checks active",
                icon: "checkmark.seal.fill",
                color: AppTheme.Colors.verificationBlue
            )
            
            VerificationSummaryCard(
                title: "Eligible",
                value: "\(viewModel.eligibleUsers.count)",
                subtitle: "Ready for review",
                icon: "star.fill",
                color: AppTheme.Colors.primary
            )
        }
    }
    
    private var eligibleSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Eligible for Blue Check")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            if viewModel.eligibleUsers.isEmpty {
                Text("No creators have unlocked the milestone yet. Keep growing the community!")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.Colors.backgroundSecondary)
                    .cornerRadius(AppTheme.CornerRadius.md)
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(viewModel.eligibleUsers) { eligible in
                        EligibleVerificationCard(eligible: eligible) {
                            Task { await viewModel.grantBadge(for: eligible.user) }
                        }
                    }
                }
            }
        }
    }
    
    private var verifiedSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Recently Verified")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            if viewModel.verifiedUsers.isEmpty {
                Text("No verified creators yet. Approve someone to kick things off.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.Colors.backgroundSecondary)
                    .cornerRadius(AppTheme.CornerRadius.md)
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(viewModel.verifiedUsers, id: \.id) { user in
                        VerifiedCreatorRow(
                            user: user,
                            onRevoke: {
                                Task { await viewModel.revokeBadge(for: user) }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Summary Card
private struct VerificationSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Eligible Card
private struct EligibleVerificationCard: View {
    let eligible: OwnerVerificationDashboardViewModel.EligibleUser
    let onGrant: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                AsyncAvatarView(url: eligible.user.profileImageURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(eligible.user.displayName)
                        .font(AppTheme.Typography.bodySemibold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("@\(eligible.user.username)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                Text(eligible.milestone.title)
                    .font(AppTheme.Typography.caption)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.backgroundSecondary)
                    .cornerRadius(AppTheme.CornerRadius.sm)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(eligible.milestone.description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                ProgressView(value: eligible.progress.percentComplete)
                    .tint(AppTheme.Colors.verificationBlue)
                
                HStack {
                    Text(eligible.progressLabel)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    Text("\(Int(eligible.progress.percentComplete * 100))%")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
            
            Button(action: onGrant) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Grant Blue Check")
                }
                .font(AppTheme.Typography.bodySemibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.Colors.verificationBlue)
                .foregroundStyle(.white)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Verified Row
private struct VerifiedCreatorRow: View {
    let user: User
    let onRevoke: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                AsyncAvatarView(url: user.profileImageURL)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.displayName)
                            .font(AppTheme.Typography.bodySemibold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(AppTheme.Colors.verificationBlue)
                    }
                    Text(user.verificationBadge?.reason ?? "Verified creator")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                if let awardDate = user.verificationBadge?.awardedAt {
                    Text(awardDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            
            Button(role: .destructive, action: onRevoke) {
                Text("Revoke Badge")
                    .font(AppTheme.Typography.caption)
            }
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

// MARK: - Avatar
private struct AsyncAvatarView: View {
    let url: String?
    
    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                CachedAsyncImage(
                    url: imageURL,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        avatarLoadingPlaceholder
                    }
                )
            } else {
                avatarFallback
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }
    
    private var avatarFallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
    
    private var avatarLoadingPlaceholder: some View {
        ZStack {
            avatarFallback
            ProgressView()
                .tint(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - View Model
@MainActor
final class OwnerVerificationDashboardViewModel: ObservableObject {
    @Published var eligibleUsers: [EligibleUser] = []
    @Published var verifiedUsers: [User] = []
    @Published var isLoading: Bool = false
    
    struct EligibleUser: Identifiable {
        let user: User
        let milestone: VerificationMilestone
        let progress: VerificationBadgeService.Eligibility
        
        var id: String { user.id }
        
        var progressLabel: String {
            switch milestone {
            case .subscribers:
                return "\(user.subscriberCount.formatted()) / \(AppConfig.Verification.subscriberMilestone.formatted()) subs"
            case .totalViews:
                return "\(user.totalViews?.formatted() ?? "0") / \(AppConfig.Verification.totalViewsMilestone.formatted()) views"
            case .creatorConsistency:
                return "\(user.videoCount) / \(AppConfig.Verification.minimumVideoCount) videos"
            case .manual:
                return "Manual review"
            }
        }
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        let users = await fetchCandidates()
        var eligible: [EligibleUser] = []
        var verified: [User] = []
        
        for user in users {
            if user.shouldShowVerificationBadge {
                verified.append(user)
                continue
            }
            
            if let eligibility = VerificationBadgeService.shared.eligibility(for: user) {
                let eligibleUser = EligibleUser(user: user, milestone: eligibility.milestone, progress: eligibility)
                eligible.append(eligibleUser)
            }
        }
        
        eligibleUsers = eligible.sorted { $0.progress.percentComplete > $1.progress.percentComplete }
        verifiedUsers = verified.sorted { (user1, user2) -> Bool in
            let date1 = user1.verificationBadge?.awardedAt ?? Date.distantPast
            let date2 = user2.verificationBadge?.awardedAt ?? Date.distantPast
            return date1 > date2
        }
    }
    
    func grantBadge(for user: User) async {
        do {
            let adminId = AuthenticationManager.shared.currentUser?.id
            let updatedUser = try await VerificationBadgeService.shared.grantBlueCheck(to: user, adminId: adminId)
            await load()
            NotificationManager.shared.showSuccess("\(updatedUser.displayName) now has a blue check")
        } catch {
            NotificationManager.shared.showError("Failed to grant badge: \(error.localizedDescription)")
        }
    }
    
    func revokeBadge(for user: User) async {
        guard let adminId = AuthenticationManager.shared.currentUser?.id else { return }
        do {
            _ = try await VerificationBadgeService.shared.revokeBlueCheck(for: user, adminId: adminId)
            await load()
        } catch {
            NotificationManager.shared.showError("Failed to revoke badge: \(error.localizedDescription)")
        }
    }
    
    private func fetchCandidates() async -> [User] {
        if let cached = try? await DatabaseService.shared.fetchAllUsers(), !cached.isEmpty {
            return cached
        }
        
        var fallback = User.sampleUsers
        if let current = AuthenticationManager.shared.currentUser {
            fallback.append(current)
        }
        return Array(Set(fallback)).sorted { $0.displayName < $1.displayName }
    }
}

