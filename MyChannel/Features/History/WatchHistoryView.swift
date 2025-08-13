//
//  WatchHistoryView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

struct WatchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var selection = Set<String>()
    @State private var query: String = ""

    private var videos: [Video] {
        // Prefer AppState-backed history ordered, else fall back to samples
        let ids = appState.watchHistory
        if ids.isEmpty {
            return Array(Video.sampleVideos.prefix(30))
        }
        let lookup = Dictionary(uniqueKeysWithValues: Video.sampleVideos.map { ($0.id, $0) })
        let mapped = ids.compactMap { lookup[$0] }
        return mapped.isEmpty ? Array(Video.sampleVideos.prefix(30)) : mapped
    }

    private var filtered: [Video] {
        guard !query.isEmpty else { return videos }
        return videos.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.creator.displayName.localizedCaseInsensitiveContains(query) ||
            $0.category.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.Colors.surface, in: Circle())
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    appState.watchHistory.removeAll()
                                }
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                            if !selection.isEmpty {
                                Button(role: .destructive) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        appState.watchHistory.removeAll { selection.contains($0) }
                                        selection.removeAll()
                                    }
                                } label: {
                                    Label("Remove Selected", systemImage: "trash.slash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            searchBar

            if filtered.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Videos you watch will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background.ignoresSafeArea())
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { video in
                        Button {
                            HapticManager.shared.impact(style: .light)
                            NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
                            dismiss()
                        } label: {
                            HistoryRow(video: video)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppTheme.Colors.background)
                    }
                    .onDelete { idxSet in
                        let idsToRemove = idxSet.map { filtered[$0].id }
                        appState.watchHistory.removeAll { idsToRemove.contains($0) }
                    }
                }
                .listStyle(.plain)
                .background(AppTheme.Colors.background)
                .environment(\.defaultMinListRowHeight, 68)
            }
        }
        .background(AppTheme.Colors.background)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextField("Search history", text: $query)
                .textFieldStyle(.plain)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct HistoryRow: View {
    let video: Video

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray6)
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Text(video.formattedDuration)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(video.creator.displayName)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("•")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(video.formattedViewCount + " views")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .font(.caption)
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .contentShape(Rectangle())
    }
}

#Preview("WatchHistoryView") {
    let state = AppState()
    state.currentUser = User.sampleUsers.first
    state.watchHistory = Array(Video.sampleVideos.prefix(10)).map { $0.id }
    return WatchHistoryView()
        .environmentObject(state)
        .preferredColorScheme(.light)
}