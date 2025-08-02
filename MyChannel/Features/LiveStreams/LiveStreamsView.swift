//
//  LiveStreamsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct LiveStreamsView: View {
    @State private var liveStreams: [LiveStreamItem] = LiveStreamItem.sampleStreams
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(liveStreams) { stream in
                        LiveStreamDetailCard(stream: stream)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Live Streams")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LiveStreamDetailCard: View {
    let stream: LiveStreamItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stream preview
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(16/9, contentMode: .fill)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            
                            Text("LIVE STREAM")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    )
                
                // Live badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.8))
                .cornerRadius(4)
                .padding(8)
            }
            
            // Stream info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: stream.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(AppTheme.Typography.headline)
                        .lineLimit(2)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text(stream.creator.displayName)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if stream.creator.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    Text("\(stream.viewerCount) watching")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct LiveStreamItem: Identifiable {
    let id: String = UUID().uuidString
    let title: String
    let creator: User
    let viewerCount: Int
    let startedAt: Date
    
    static let sampleStreams: [LiveStreamItem] = [
        LiveStreamItem(
            title: "Live Coding Session - Building a SwiftUI App",
            creator: User.sampleUsers[0],
            viewerCount: 1245,
            startedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        ),
        LiveStreamItem(
            title: "Digital Art Speed Paint",
            creator: User.sampleUsers[1],
            viewerCount: 856,
            startedAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date()) ?? Date()
        ),
        LiveStreamItem(
            title: "Gaming Tournament Finals",
            creator: User.sampleUsers[2],
            viewerCount: 3421,
            startedAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        )
    ]
}

#Preview {
    LiveStreamsView()
}