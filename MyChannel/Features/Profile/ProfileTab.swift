//
//  ProfileTab.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - Profile Tab Enum
enum ProfileTab: String, CaseIterable, Identifiable {
    case videos = "videos"
    case shorts = "shorts" 
    case playlists = "playlists"
    case community = "community"
    case about = "about"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .videos: return "Videos"
        case .shorts: return "Flicks"
        case .playlists: return "Playlists"
        case .community: return "Community"
        case .about: return "About"
        }
    }
    
    var iconName: String {
        switch self {
        case .videos: return "play.rectangle"
        case .shorts: return "play.rectangle.on.rectangle"
        case .playlists: return "list.bullet"
        case .community: return "person.3"
        case .about: return "info.circle"
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .videos: return "Videos tab"
        case .shorts: return "Flicks tab"
        case .playlists: return "Playlists tab"
        case .community: return "Community tab"
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