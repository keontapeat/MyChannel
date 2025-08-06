//
//  ProfileHeaderView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileHeaderView: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool
    @Binding var selectedTab: ProfileTab
    
    private let headerHeight: CGFloat = 365
    private let profileImageSize: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Background Banner - FILLS EVERYTHING INCLUDING TAB AREA
            GeometryReader { geometry in
                ZStack {
                    if let bannerURL = user.bannerImageURL {
                        CachedAsyncImage(url: URL(string: bannerURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height + geometry.safeAreaInsets.top + 60
                                )
                                .offset(y: -geometry.safeAreaInsets.top - 15)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary.opacity(0.8), AppTheme.Colors.secondary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height + geometry.safeAreaInsets.top + 60
                                )
                                .offset(y: -geometry.safeAreaInsets.top - 15)
                        }
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary.opacity(0.8), AppTheme.Colors.secondary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height + geometry.safeAreaInsets.top + 60
                            )
                            .offset(y: -geometry.safeAreaInsets.top - 15)
                    }
                    
                    // Adaptive gradient overlay that blends with any background
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height + geometry.safeAreaInsets.top + 60
                    )
                    .offset(y: -geometry.safeAreaInsets.top - 15)
                }
            }
            
            // Header Content + Tab Navigation Combined
            VStack(spacing: 0) {
                // Top spacer
                Spacer(minLength: 20)
                
                // Settings Button
                HStack {
                    Spacer()
                    
                    Button {
                        showingSettings = true
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Profile Content
                VStack(spacing: 12) {
                    // Profile Image with better contrast
                    ZStack {
                        if let profileImageURL = user.profileImageURL {
                            CachedAsyncImage(url: URL(string: profileImageURL)) { image in
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
                        } else {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                )
                        }
                    }
                    .frame(width: profileImageSize, height: profileImageSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 4)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    // User Info with better readability
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text(user.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                        }
                        
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        if let bio = user.bio {
                            Text(bio)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.95))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .padding(.horizontal, 8)
                        }
                    }
                    
                    // Stats with better visibility
                    HStack(spacing: 24) {
                        VStack(spacing: 2) {
                            Text("\(user.subscriberCount.formatted())")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            
                            Text("Subscribers")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        
                        Rectangle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 1, height: 28)
                        
                        VStack(spacing: 2) {
                            Text("\(user.videoCount)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            
                            Text("Videos")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        
                        if let totalViews = user.totalViews {
                            Rectangle()
                                .fill(.white.opacity(0.4))
                                .frame(width: 1, height: 28)
                            
                            VStack(spacing: 2) {
                                Text(formatViews(totalViews))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                
                                Text("Views")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            }
                        }
                    }
                    
                    // Action Buttons with better materials
                    HStack(spacing: 12) {
                        Button {
                            showingEditProfile = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Edit Profile")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        Button {
                            withAnimation(.spring()) {
                                isFollowing.toggle()
                            }
                            HapticManager.shared.impact(style: .medium)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isFollowing ? "person.fill.checkmark" : "person.fill.badge.plus")
                                    .font(.caption)
                                Text(isFollowing ? "Following" : "Follow")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                isFollowing ? 
                                    .black.opacity(0.3) : 
                                    AppTheme.Colors.primary.opacity(0.9)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .scaleEffect(isFollowing ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFollowing)
                    }
                }
                .padding(.horizontal, 20)
                
                // BREATHING ROOM 
                Spacer(minLength: 30)
                
                // TAB NAVIGATION BUILT RIGHT INTO THE HEADER - NO GAP POSSIBLE!
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(ProfileTab.allCases) { tab in
                                ProfileTabButton(
                                    tab: tab,
                                    isSelected: selectedTab == tab,
                                    user: user,
                                    action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            selectedTab = tab
                                        }
                                        HapticManager.shared.impact(style: .light)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 56)
                }
                .background(Color.clear)
                .overlay(
                    Rectangle()
                        .fill(AppTheme.Colors.textSecondary.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
            }
        }
        .frame(height: headerHeight + 56)
        .clipped()
    }
    
    private func formatViews(_ views: Int) -> String {
        if views >= 1_000_000_000 {
            return String(format: "%.1fB", Double(views) / 1_000_000_000)
        } else if views >= 1_000_000 {
            return String(format: "%.1fM", Double(views) / 1_000_000)
        } else if views >= 1_000 {
            return String(format: "%.1fK", Double(views) / 1_000)
        } else {
            return "\(views)"
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ProfileHeaderView(
            user: User.sampleUsers[0],
            scrollOffset: 0,
            isFollowing: .constant(false),
            showingEditProfile: .constant(false),
            showingSettings: .constant(false),
            selectedTab: .constant(.videos)
        )
        .ignoresSafeArea(edges: .top)
        
        ScrollView {
            Text("NO MORE GAP POSSIBLE! 🔥")
                .padding(.top, 50)
        }
    }
}