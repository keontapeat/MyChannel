// MyChannelTVApp.swift
// MyChannel tvOS — App entry point
//
// SwiftUI @main for Apple TV. Boots the AppState + AuthenticationManager
// shared singletons (same as iOS) and presents TVContentView.

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct MyChannelTVApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager.shared

    init() {
        #if canImport(FirebaseCore)
        // Firebase is configured by FirebaseAppDelegate on iOS.
        // On tvOS we call configure() directly since there is no UIApplicationDelegate.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TVContentView()
                .environmentObject(appState)
                .environmentObject(authManager)
        }
    }
}
