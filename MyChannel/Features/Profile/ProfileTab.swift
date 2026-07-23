//
//  ProfileTab.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - Profile Tab Enum
// 🔥 MYCHANEL PARITY: Channel tabs — Home · Videos · Flicks · Live · Playlists · Posts · Downloads · About
enum ProfileTab: String, CaseIterable, Identifiable {
    case videos = "videos"
    case flicks = "flicks"
    case live = "live"
    case playlists = "playlists"
    case community = "community"
    case downloads = "downloads"
    case about = "about"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .videos: return "Videos"
        case .flicks: return "Flicks"
        case .live: return "Live"
        case .playlists: return "Playlists"
        case .community: return "Posts"
        case .downloads: return "Downloads"
        case .about: return "About"
        }
    }
    
    var iconName: String {
        switch self {
        case .videos: return "play.rectangle"
        case .flicks: return "play.rectangle.on.rectangle"
        case .live: return "dot.radiowaves.left.and.right"
        case .playlists: return "list.bullet"
        case .community: return "text.bubble"
        case .downloads: return "arrow.down.circle"
        case .about: return "info.circle"
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .videos: return "Videos tab"
        case .flicks: return "Flicks tab"
        case .live: return "Live tab"
        case .playlists: return "Playlists tab"
        case .community: return "Posts tab"
        case .downloads: return "Downloads tab"
        case .about: return "About tab"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Profile Tabs")
            .font(AppTheme.Typography.largeTitle)
            .padding()
        
        HStack {
            ForEach(ProfileTab.allCases) { tab in
                VStack {
                    Image(systemName: tab.iconName)
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text(tab.title)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.background)
}