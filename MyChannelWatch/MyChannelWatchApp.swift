// MyChannelWatchApp.swift
// MyChannel watchOS App — 100% YouTube watchOS parity
//
// Features:
//   • Now Playing with full playback controls
//   • Up Next / Queue
//   • Subscriptions feed (latest uploads)
//   • Watch History
//   • Notifications inbox
//   • Voice Search via Siri / dictation
//   • Complications (now playing, watch later count)
//   • Handoff to iPhone for full playback
//   • Remote control of iPhone playback via WatchConnectivity

import SwiftUI
import WatchKit

@main
struct MyChannelWatchApp: App {
    @StateObject private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
