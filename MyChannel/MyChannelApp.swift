//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVFoundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UserNotifications

@main
struct MyChannelApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) var firebaseDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authManager: AuthenticationManager = AuthenticationManager.shared
    @StateObject private var appState: AppState = AppState()
    @StateObject private var globalPlayerManager: GlobalVideoPlayerManager = GlobalVideoPlayerManager.shared
    
    init() {
        print("🚀 MyChannelApp init started...")
        
        // 🔥 Clear cached thumbnails to fix any stale/broken images (v2.1 fix)
        let cacheVersion = "thumbnail_cache_v2.1"
        if UserDefaults.standard.string(forKey: "thumbnail_cache_version") != cacheVersion {
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.set(cacheVersion, forKey: "thumbnail_cache_version")
            print("🔥 Cleared thumbnail cache for fresh images")
        }
        
        // 🔥🛡️ NUCLEAR VALIDATION - Crash immediately if any Wikipedia URLs exist
        // This prevents broken thumbnails from EVER appearing in the app
        LiveTVChannel.validateAllChannelURLs()
        
        // Configure Firebase as early as possible to avoid startup warnings
        FirebaseManager.shared.configureIfPossible()
        setupAppearance()
        configureAudioSession()
        
        // 🔐 SECURITY: Migrate API keys from Info.plist to Keychain (App Store requirement)
        Task { @MainActor in
            if !UserDefaults.standard.bool(forKey: "keychain_migration_complete") {
                KeychainManager.shared.migrateFromInfoPlist()
            }
        }
        
        // Force onboarding to be completed - we don't want onboarding flow anymore
        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
        
        print("✅ MyChannelApp init completed")
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            SplashContainer()
                .environmentObject(authManager)
                .environmentObject(appState)
                .environmentObject(globalPlayerManager)
                .onAppear {
                    print("📱 App appeared with MC logo splash!")
                    
                    // 🏥 Start MyChannel Doctor 24/7 monitoring
                    MyChannelDoctorService.shared.startMonitoring()
                    
                    // Start performance optimization after UI is ready
                    PerformanceOptimizer.shared.optimizeAppLaunch()
                    
                    // Performance monitoring automatically starts in debug builds
                    #if DEBUG
                    print("⚡ [Performance] Monitoring active - shared instance initialized")
                    #endif
                    
                    // 🔥 INITIALIZE SMART USER SEEDER: Populate app with AI-generated users
                    Task {
                        await SmartUserSeederService.shared.initialize()
                    }
                    
                    // 🔥 INITIALIZE LIVE TV: Fetch fresh channel data for 24/7 reliability
                    Task {
                        await LiveTVService.shared.initialize()
                        print("📺 [LiveTV] Initialized with fresh channel data")
                    }
                    
                    // Ensure auth state is checked at launch and sync to AppState
                    authManager.checkAuthenticationStatus()
                    if let current = authManager.currentUser {
                        appState.updateUser(current)
                    } else {
                        appState.clearUser()
                    }
                    Task {
                        _ = await PushNotificationService.shared.getAuthorizationStatus()
                    }
                }
                .onChange(of: authManager.currentUser) { newUser in
                    if let user = newUser {
                        appState.updateUser(user)
                    } else {
                        appState.clearUser()
                    }
                }
                .onChange(of: authManager.isAuthenticated) { isAuth in
                    if !isAuth { appState.clearUser() }
                }
                .onChange(of: scenePhase) { newPhase in
                    print("🎬 [MyChannelApp] ScenePhase changed to \(newPhase)")
                    
                    // 🔥 LiveTV: Handle app lifecycle for 24/7 channel reliability
                    Task { @MainActor in
                        switch newPhase {
                        case .active:
                            LiveTVManager.shared.onAppBecameActive()
                        case .background:
                            LiveTVManager.shared.onAppEnteredBackground()
                        default:
                            break
                        }
                    }
                }
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    #endif
                    DeepLinkManager.shared.handle(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    _ = DeepLinkManager.shared.handleUniversalLink(activity)
                }
        }
    }
    
    private func setupAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.background)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.textPrimary),
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.background)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        UITextField.appearance().tintColor = UIColor(AppTheme.Colors.primary)
        UITextView.appearance().tintColor = UIColor(AppTheme.Colors.primary)
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
            print("✅ [MyChannelApp] Audio session configured for background playback")
        } catch {
            print("⚠️ [MyChannelApp] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}