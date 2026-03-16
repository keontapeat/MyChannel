//
//  LiveNowSection.swift
//  MyChannel
//
//  Horizontal "Live Now" section for HomeView showing active live streams from Firestore.
//

import SwiftUI

struct LiveNowSection: View {
    @ObservedObject private var liveManager = LiveStreamManager.shared
    let onSelectStream: (FirestoreLiveStream) -> Void

    var body: some View {
        if !liveManager.activeStreams.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Live Now")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    Spacer()
                    Text("\(liveManager.activeStreams.count) streaming")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(.horizontal, 20)

                // Horizontal scroll of live cards
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(liveManager.activeStreams) { stream in
                            LiveNowCard(stream: stream)
                                .onTapGesture {
                                    HapticManager.shared.impact(style: .medium)
                                    onSelectStream(stream)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Live Now Card
struct LiveNowCard: View {
    let stream: FirestoreLiveStream

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail area with LIVE badge
            ZStack(alignment: .topLeading) {
                // Background with creator avatar or gradient
                ZStack {
                    LinearGradient(
                        colors: [gradientColor.opacity(0.8), Color.black.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Creator avatar centered
                    if !stream.creatorAvatar.isEmpty, let url = URL(string: stream.creatorAvatar) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            avatarFallback
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.red, lineWidth: 2)
                        )
                    } else {
                        avatarFallback
                    }
                }
                .frame(width: 200, height: 112)
                .cornerRadius(10)

                // LIVE badge
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
                .padding(6)

                // Viewer count badge (bottom right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 9))
                            Text("\(formattedViewerCount)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(6)
                    }
                }
                .frame(width: 200, height: 112)
            }

            // Stream info
            VStack(alignment: .leading, spacing: 3) {
                Text(stream.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(stream.creatorName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    if stream.creatorIsVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }

                Text(stream.category)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .frame(width: 200)
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(stream.creatorName.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var formattedViewerCount: String {
        if stream.viewerCount >= 1000 {
            return String(format: "%.1fK", Double(stream.viewerCount) / 1000.0)
        }
        return "\(stream.viewerCount)"
    }

    private var gradientColor: Color {
        switch stream.category.lowercased() {
        case "gaming": return .green
        case "music": return .purple
        case "education": return .blue
        case "sports": return .orange
        default: return .indigo
        }
    }
}

#Preview("Live Now Section") {
    VStack {
        LiveNowSection(onSelectStream: { _ in })
            .onAppear {
                LiveStreamManager.shared.activeStreams = LiveStreamManager.sampleStreams
            }
    }
    .background(Color(.systemBackground))
}
