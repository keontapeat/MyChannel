// LibraryView.swift
// YouTube watchOS parity: Watch History, Watch Later, Queue.

import SwiftUI
import WatchKit

struct LibraryView: View {
    @EnvironmentObject var store: WatchStore
    @State private var section: Section = .history

    enum Section: String, CaseIterable {
        case history  = "History"
        case watchLater = "Later"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)
                .padding(.top, 4)

                let videos = section == .history ? store.watchHistory : store.watchLater

                if videos.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: section == .history ? "clock" : "bookmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(section == .history ? "No watch history" : "Watch Later is empty")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(videos) { video in
                            WatchVideoRow(video: video)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if section == .watchLater {
                                        Button(role: .destructive) {
                                            store.removeFromWatchLater(video.id)
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                }
                                .onTapGesture {
                                    store.openVideo(video.id)
                                    WKInterfaceDevice.current().play(.click)
                                }
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Library")
            .refreshable {
                await store.loadFeedFromFirestore()
            }
        }
    }
}
