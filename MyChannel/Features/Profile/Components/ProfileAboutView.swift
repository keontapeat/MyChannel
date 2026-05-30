import SwiftUI

// MARK: - Profile About View
struct ProfileAboutView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 24) {
            // Channel stats
            ProfileStatsSection(user: user)
            
            // Description
            if let bio = user.bio {
                ProfileDescriptionSection(bio: bio)
            }
            
            // Social links
            if !user.socialLinks.isEmpty {
                ProfileSocialLinksSection(socialLinks: user.socialLinks)
            }
            
            // Additional info
            ProfileAdditionalInfoSection(user: user)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Stats Section
struct ProfileStatsSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Channel Statistics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ProfileStatCard(
                    title: "Subscribers",
                    value: "\(user.subscriberCount.formatted())",
                    icon: "person.2.fill",
                    color: AppTheme.Colors.primary
                )
                
                ProfileStatCard(
                    title: "Videos",
                    value: "\(user.videoCount)",
                    icon: "play.rectangle.fill",
                    color: AppTheme.Colors.secondary
                )
                
                if let totalViews = user.totalViews {
                    ProfileStatCard(
                        title: "Total Views",
                        value: "\(totalViews.formatted())",
                        icon: "eye.fill",
                        color: .green
                    )
                }
                
                ProfileStatCard(
                    title: "Joined",
                    value: user.createdAt.formatted(.dateTime.year().month(.abbreviated)),
                    icon: "calendar.badge.plus",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Stat Card
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Profile Description Section
struct ProfileDescriptionSection: View {
    let bio: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(bio)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Social Links Section
struct ProfileSocialLinksSection: View {
    let socialLinks: [SocialLink]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(socialLinks) { link in
                    ProfileSocialLinkCard(link: link)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Additional Info Section
struct ProfileAdditionalInfoSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                if let location = user.location {
                    ProfileInfoRow(icon: "location.fill", title: "Location", value: location)
                }
                
                if let website = user.website {
                    ProfileInfoRow(icon: "globe", title: "Website", value: website)
                }
                
                ProfileInfoRow(
                    icon: "calendar.badge.plus",
                    title: "Joined",
                    value: user.createdAt.formatted(.dateTime.day().month().year())
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Info Row
struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(width: 20, height: 20)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Profile Social Link Card (renamed to avoid conflict with EditProfileView)
struct ProfileSocialLinkCard: View {
    let link: SocialLink
    
    var body: some View {
        Button(action: {
            // Open link
        }) {
            HStack(spacing: 8) {
                Image(systemName: link.platform.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 20, height: 20)
                
                Text(link.platform.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
