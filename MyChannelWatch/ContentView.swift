// ContentView.swift
// MyChannel watchOS — root navigation

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: WatchStore
    @State private var tab: Tab = .nowPlaying

    enum Tab { case nowPlaying, feed, library, notifications }

    var body: some View {
        TabView(selection: $tab) {
            NowPlayingView()
                .tag(Tab.nowPlaying)

            FeedView()
                .tag(Tab.feed)

            LibraryView()
                .tag(Tab.library)

            NotificationsView()
                .tag(Tab.notifications)
        }
        .tabViewStyle(.page)
    }
}
