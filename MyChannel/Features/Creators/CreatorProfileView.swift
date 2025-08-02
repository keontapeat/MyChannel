//
//  CreatorProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct CreatorProfileView: View {
    let creator: User
    @State private var isFollowing: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Creator header
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(creator.displayName)
                                    .font(AppTheme.Typography.title1)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.title2)
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            
                            Text("@\(creator.username)")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            if let bio = creator.bio {
                                Text(bio)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Stats
                        HStack(spacing: 32) {
                            VStack(spacing: 4) {
                                Text("\(creator.subscriberCount.formatted())")
                                    .font(AppTheme.Typography.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("Subscribers")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(creator.videoCount)")
                                    .font(AppTheme.Typography.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("Videos")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            if let totalViews = creator.totalViews {
                                VStack(spacing: 4) {
                                    Text("\(totalViews.formatted())")
                                        .font(AppTheme.Typography.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Text("Views")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                        
                        // Follow button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFollowing.toggle()
                            }
                        }) {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(AppTheme.Typography.bodyMedium)
                                .foregroundColor(isFollowing ? AppTheme.Colors.textPrimary : .white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    ZStack {
                                        if isFollowing {
                                            AppTheme.Colors.surface
                                        } else {
                                            AppTheme.Colors.gradient
                                        }
                                    }
                                )
                                .cornerRadius(AppTheme.CornerRadius.md)
                        }
                    }
                    
                    // Placeholder content
                    VStack(spacing: 16) {
                        Text("Creator Content")
                            .font(AppTheme.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Videos, playlists, and other content would appear here")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(creator.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CreatorProfileView(creator: User.sampleUsers[0])
}