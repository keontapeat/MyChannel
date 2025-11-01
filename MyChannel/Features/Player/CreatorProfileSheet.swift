//
//  CreatorProfileSheet.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI

struct CreatorProfileSheet: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var isSubscribed = false
    @State private var showingFullProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Profile Image
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        // Creator Info
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(creator.displayName)
                                    .font(.title2.bold())
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.title3)
                                }
                            }
                            
                            Text("@\(creator.username)")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("\(formatCount(creator.subscriberCount)) subscribers")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        // Bio
                        if let bio = creator.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        // Subscribe Button
                        Button(action: toggleSubscription) {
                            HStack(spacing: 8) {
                                Image(systemName: isSubscribed ? "bell.fill" : "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(isSubscribed ? "Subscribed" : "Subscribe")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(isSubscribed ? AppTheme.Colors.textPrimary : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // View Channel Button
                        Button(action: { showingFullProfile = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("View Channel")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(AppTheme.Colors.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Stats Section
                    HStack(spacing: 32) {
                        CreatorStatItem(title: "Videos", value: formatCount(creator.videoCount))
                        CreatorStatItem(title: "Subscribers", value: formatCount(creator.subscriberCount))
                        CreatorStatItem(title: "Views", value: formatCount(creator.totalViews ?? 0))
                    }
                    .padding(.horizontal, 20)
                    
                    // Recent Videos Preview
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Videos")
                                .font(.headline.bold())
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button("View All") {
                                showingFullProfile = true
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Video.sampleVideos.prefix(5)) { video in
                                    CompactVideoCard(video: video)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .onAppear {
            isSubscribed = appState.isSubscribedTo(creator.id)
        }
        .fullScreenCover(isPresented: $showingFullProfile) {
            // Navigate to full profile view
            ProfileView()
                .environmentObject(authManager)
                .environmentObject(appState)
        }
    }
    
    private func toggleSubscription() {
        HapticManager.shared.impact(style: .medium)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isSubscribed.toggle()
        }
        appState.toggleSubscription(for: creator.id)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Supporting Views

struct CreatorStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

struct CompactVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 140, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Video Info
            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(formatCount(video.viewCount)) views")
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(width: 140)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

#Preview {
    CreatorProfileSheet(creator: User.defaultUser)
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager.shared)
}
