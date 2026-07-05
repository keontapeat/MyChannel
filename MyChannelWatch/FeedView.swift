// FeedView.swift
// YouTube watchOS parity: Trending / Subscriptions feed with voice search.

import SwiftUI
import WatchKit

struct FeedView: View {
    @EnvironmentObject var store: WatchStore
    @State private var tab: FeedTab = .trending
    @State private var showSearch = false
    @State private var searchQuery = ""

    enum FeedTab: String, CaseIterable {
        case trending = "Trending"
        case subscriptions = "Latest"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $tab) {
                    ForEach(FeedTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)
                .padding(.top, 4)

                // Feed list
                let videos = tab == .trending ? store.trendingVideos : store.subscriptionFeed
                if store.isLoadingFeed && videos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if videos.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: tab == .trending ? "chart.line.uptrend.xyaxis" : "person.2.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(tab == .trending ? "No trending videos" : "No new uploads")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(videos) { video in
                        WatchVideoRow(video: video)
                            .onTapGesture {
                                store.openVideo(video.id)
                                WKInterfaceDevice.current().play(.click)
                            }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                VoiceSearchView { query in
                    searchQuery = query
                    showSearch = false
                    store.sendCommand("search", payload: ["query": query])
                }
            }
            .refreshable {
                await store.loadFeedFromFirestore()
            }
        }
    }
}

// MARK: - Video row

struct WatchVideoRow: View {
    let video: WatchVideo

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: video.thumbnailURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 54, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .bottomTrailing) {
                if video.isLive {
                    Text("LIVE")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(2)
                } else if video.durationSeconds > 0 {
                    Text(formatDuration(video.durationSeconds))
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.footnote.bold())
                    .lineLimit(2)
                Text(video.channelName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ secs: Int) -> String {
        let m = secs / 60; let s = secs % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Voice Search

struct VoiceSearchView: View {
    let onResult: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.red)

            Text("Voice Search")
                .font(.headline)

            TextField("Search…", text: $query)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit {
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        onResult(query.trimmingCharacters(in: .whitespaces))
                    }
                }

            Button("Search") {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    onResult(query.trimmingCharacters(in: .whitespaces))
                }
            }
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
