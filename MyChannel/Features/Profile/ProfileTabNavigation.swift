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
    
    var body: some View {
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

struct ProfileTabButton: View {
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
            user: User.sampleUsers[0]
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