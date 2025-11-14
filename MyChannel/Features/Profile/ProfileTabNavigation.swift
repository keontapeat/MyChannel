//
//  ProfileTabNavigation.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileTabNavigation: View {
    @Binding var selectedTab: ProfileTab
    let user: User
    let scrollOffset: CGFloat
    
    private var isPinned: Bool {
        scrollOffset < -10
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ProfileTab.allCases) { tab in
                            ProfileTabButton(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                user: user,
                                action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedTab = tab
                                        // Scroll to selected tab to ensure it's visible
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(tab.id, anchor: .center)
                                            }
                                        }
                                    }
                                    HapticManager.shared.impact(style: .light)
                                }
                            )
                            .id(tab.id)
                            .fixedSize(horizontal: true, vertical: false) // Prevent tabs from shrinking horizontally
                        }
                    }
                    .padding(.horizontal, 20) // Add horizontal padding so tabs aren't cut off
                    .padding(.vertical, 8)
                    .frame(minHeight: 56) // Ensure minimum height
                }
                .frame(height: 56)
            }
        }
        .background {
            if isPinned {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                Color.clear
            }
        }
        .ignoresSafeArea(edges: .horizontal) // ensure material background is edge-to-edge
        .overlay(
            Group {
                if isPinned {
                    Rectangle()
                        .fill(AppTheme.Colors.textSecondary.opacity(0.1))
                        .frame(height: 0.5)
                        .transition(.opacity)
                }
            },
            alignment: .bottom
        )
    }
}

struct ProfileTabButton: View {
    let tab: ProfileTab
    let isSelected: Bool
    let user: User
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Icon (YouTube-style: only show when selected or on hover)
                    if isSelected {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    Text(tab.title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(
                            isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary
                        )
                    
                    if let count = getTabCount(for: tab) {
                        Text("\(count)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                
                // Selection Indicator (YouTube-style: bottom border)
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(height: 2)
                    .scaleEffect(x: isSelected ? 1.0 : 0.0, y: 1.0, anchor: .center)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    private func getTabCount(for tab: ProfileTab) -> Int? {
        switch tab {
        case .videos:
            return user.videoCount > 0 ? user.videoCount : nil
        case .shorts:
            return user.videoCount > 5 ? user.videoCount / 3 : nil // Estimate flicks count
        case .playlists:
            return user.videoCount > 10 ? user.videoCount / 8 : nil // Estimate playlists count
        case .community:
            return user.subscriberCount > 1000 ? 12 : nil // Mock community posts
        case .about:
            return nil // About doesn't need a count
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 365)
            .overlay(
                Text("Header Background")
                    .foregroundColor(.white)
                    .font(.title)
            )
        
        ProfileTabNavigation(
            selectedTab: .constant(.videos),
            user: User.sampleUsers[0],
            scrollOffset: 0
        )
        
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<20, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Item \(index)")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("PERFECTLY FLUSH! NO GAPS!")
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
        .background(AppTheme.Colors.background)
    }
}