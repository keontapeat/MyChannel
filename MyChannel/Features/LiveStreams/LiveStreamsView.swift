//
//  LiveStreamsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct LiveStreamsView: View {
    @ObservedObject private var liveManager = LiveStreamManager.shared
    @State private var selectedStream: FirestoreLiveStream?

    var body: some View {
        NavigationStack {
            ScrollView {
                if liveManager.activeStreams.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 60)
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text("No one is live right now")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("Check back later or go live yourself!")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(liveManager.activeStreams) { stream in
                            LiveStreamDetailCard(stream: stream)
                                .padding(.horizontal)
                                .onTapGesture {
                                    selectedStream = stream
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Live Streams")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                liveManager.startListening()
            }
            .fullScreenCover(item: $selectedStream) { stream in
                LiveViewerView(stream: stream)
            }
        }
    }
}

extension FirestoreLiveStream: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct LiveStreamDetailCard: View {
    @ObservedObject private var liveManager = LiveStreamManager.shared
    let stream: FirestoreLiveStream

    private var viewerCount: Int {
        liveManager.viewerCount(for: stream.id, fallback: stream.viewerCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stream preview
            ZStack(alignment: .topLeading) {
                ZStack {
                    LinearGradient(
                        colors: [categoryColor.opacity(0.7), Color.black.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 8) {
                        if !stream.creatorAvatar.isEmpty, let url = URL(string: stream.creatorAvatar) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                avatarFallback
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.red, lineWidth: 2))
                        } else {
                            avatarFallback
                        }

                        Text("LIVE STREAM")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .aspectRatio(16/9, contentMode: .fill)
                .cornerRadius(AppTheme.CornerRadius.md)

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
                .background(Color.red)
                .cornerRadius(4)
                .padding(8)

                // Viewer count (bottom right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                            Text("\(viewerCount)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(8)
                    }
                }
            }

            // Stream info
            HStack(spacing: 12) {
                if !stream.creatorAvatar.isEmpty, let url = URL(string: stream.creatorAvatar) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(stream.creatorName.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(AppTheme.Typography.headline)
                        .lineLimit(2)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Text(stream.creatorName)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        if stream.creatorIsVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(viewerCount) watching")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text(stream.category)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
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

    private var avatarFallback: some View {
        Circle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 60, height: 60)
            .overlay(
                Text(String(stream.creatorName.prefix(1)).uppercased())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var categoryColor: Color {
        switch stream.category.lowercased() {
        case "gaming": return .green
        case "music": return .purple
        case "education": return .blue
        case "sports": return .orange
        default: return .indigo
        }
    }
}

#Preview {
    LiveStreamsView()
}