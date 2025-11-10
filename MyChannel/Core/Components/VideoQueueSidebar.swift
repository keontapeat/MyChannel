//
//  VideoQueueSidebar.swift
//  MyChannel
//
//  YouTube Parity: Queue management sidebar
//  Created for MyChannel by AI Assistant
//

import SwiftUI

/// YouTube-style queue sidebar for managing video queue
struct VideoQueueSidebar: View {
    @ObservedObject var globalPlayer: GlobalVideoPlayerManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Up Next")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface)
            
            // Queue list
            if globalPlayer.videoQueue.isEmpty {
                emptyQueueView
            } else {
                queueListView
            }
        }
        .frame(width: 320)
        .background(AppTheme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private var emptyQueueView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("Queue is Empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Add videos to your queue to watch them next")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var queueListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(globalPlayer.videoQueue.enumerated()), id: \.element.id) { index, video in
                    QueueVideoRow(
                        video: video,
                        isCurrent: index == globalPlayer.queueIndex,
                        onTap: {
                            // Jump to video in queue
                            globalPlayer.queueIndex = index
                            globalPlayer.playVideo(video, showFullscreen: true, queue: globalPlayer.videoQueue)
                        },
                        onRemove: {
                            // Remove from queue
                            var newQueue = globalPlayer.videoQueue
                            newQueue.remove(at: index)
                            globalPlayer.videoQueue = newQueue
                            if globalPlayer.queueIndex >= newQueue.count {
                                globalPlayer.queueIndex = max(0, newQueue.count - 1)
                            }
                        }
                    )
                }
            }
        }
    }
}

struct QueueVideoRow: View {
    let video: Video
    let isCurrent: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCurrent ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
                )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(formatViewCount(video.viewCount)) views")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if isCurrent {
                            Text("• Now")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                }
                
                Spacer()
                
                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isCurrent ? AppTheme.Colors.primary.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

