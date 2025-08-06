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
                                    height: geometry.size.height + geometry.safeAreaInsets.top + 56
                                )
                                .offset(y: -geometry.safeAreaInsets.top - 10)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height + geometry.safeAreaInsets.top + 56
                                )
                                .offset(y: -geometry.safeAreaInsets.top - 10)
                        }
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height + geometry.safeAreaInsets.top + 56
                            )
                            .offset(y: -geometry.safeAreaInsets.top - 10)
                    }
                    
                    // Gradient Overlay - FILLS EVERYTHING
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height + geometry.safeAreaInsets.top + 56
                    )
                    .offset(y: -geometry.safeAreaInsets.top - 10)
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
                            .background(
                                .black.opacity(0.4),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Profile Content
                VStack(spacing: 10) {
                    // Profile Image
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
                            .stroke(.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // User Info
                    VStack(spacing: 3) {
                        HStack(spacing: 6) {
                            Text(user.displayName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        if let bio = user.bio {
                            Text(bio)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    
                    // Stats
                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("\(user.subscriberCount.formatted())")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Subscribers")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 1, height: 24)
                        
                        VStack(spacing: 2) {
                            Text("\(user.videoCount)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Videos")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let totalViews = user.totalViews {
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 1, height: 24)
                            
                            VStack(spacing: 2) {
                                Text(formatViews(totalViews))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Views")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 10) {
                        Button {
                            showingEditProfile = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("Edit Profile")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                isFollowing ? 
                                    .white.opacity(0.2) : 
                                    AppTheme.Colors.primary.opacity(0.8),
                                in: RoundedRectangle(cornerRadius: 16)
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

struct AProfileTabButton: View {
    let tab: ProfileTab
    let isSelected: Bool
    let user: User
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(tab.title)
                        .font(.system(size: 15, weight: .medium))
                    
                    if let count = getTabCount(for: tab) {
                        Text("(\(count))")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .foregroundColor(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Selection Indicator
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppTheme.Colors.primary)
                    .frame(height: 3)
                    .scaleEffect(x: isSelected ? 1.0 : 0.0, y: 1.0, anchor: .center)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    private func getTabCount(for tab: ProfileTab) -> Int? {
        switch tab {
        case .videos:
            return user.videoCount > 0 ? user.videoCount : nil
        case .shorts:
            return user.videoCount > 5 ? user.videoCount / 3 : nil
        case .playlists:
            return user.videoCount > 10 ? user.videoCount / 8 : nil
        case .community:
            return user.subscriberCount > 1000 ? 12 : nil
        case .about:
            return nil
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