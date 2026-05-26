//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVFoundation
import AppIntents
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UserNotifications

// 🔥 Bootstrap Firebase BEFORE any SwiftUI @StateObject stored properties initialize.
// Swift evaluates stored property initializers before the App struct's init body runs,
// so any `AuthenticationManager.shared` access from a @StateObject would otherwise fire
// before `FirebaseAppDelegate.application(_:didFinishLaunching…)`. Referencing this
// lazy-evaluated `let` forces FirebaseApp.configure() to run on first touch.
private let __bootstrapFirebase: Void = {
    FirebaseManager.shared.configureIfPossible()
}()

// Force execution at file load time to avoid any early Firebase usage warnings
private let __forceFirebaseBootstrap: Void = { _ = __bootstrapFirebase }()

@main
struct MyChannelApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) var firebaseDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authManager: AuthenticationManager = {
        _ = __bootstrapFirebase
        return AuthenticationManager.shared
    }()
    @StateObject private var appState: AppState = AppState.shared
    @StateObject private var globalPlayerManager: GlobalVideoPlayerManager = GlobalVideoPlayerManager.shared
    @ObservedObject private var settingsService: SettingsService = SettingsService.shared
    
    init() {
        let initStartTime = Date()
        print("🚀 MyChannelApp init started...")
        
        // 🔥 PERFORMANCE: Only critical synchronous operations in init
        setupAppearance()
        configureAudioSession()
        
        // Force onboarding to be completed - we don't want onboarding flow anymore
        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
        
        // 🔥 DEFERRED: Move all heavy operations to background
        Task { @MainActor in
            // Clear cache in background
            let cacheVersion = "thumbnail_cache_v2.1"
            if UserDefaults.standard.string(forKey: "thumbnail_cache_version") != cacheVersion {
                URLCache.shared.removeAllCachedResponses()
                UserDefaults.standard.set(cacheVersion, forKey: "thumbnail_cache_version")
                print("🔥 Cleared thumbnail cache for fresh images")
            }
            
            // 🔐 SECURITY: Migrate API keys in background
            if !UserDefaults.standard.bool(forKey: "keychain_migration_complete") {
                KeychainManager.shared.migrateFromInfoPlist()
            }
            
            #if DEBUG
            // Validation in background
            Task { LiveTVChannel.validateAllChannelURLs() }
            #endif
            
            // 🔥 STRONGER: Warmup Flicks on app launch for instant playback
            NuclearFlicksViewModel.warmupOnLaunch()
        }
        
        let initTime = Date().timeIntervalSince(initStartTime)
        print("✅ MyChannelApp init completed in \(Int(initTime * 1000))ms")
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            SplashContainer()
                .environmentObject(authManager)
                .environmentObject(appState)
                .environmentObject(globalPlayerManager)
                .preferredColorScheme(appState.overrideColorScheme)
                .onAppear {
                    print("📱 App appeared with MC logo splash!")
                    
                    // 🚀 LAZY SERVICE MANAGER: Optimized initialization
                    Task {
                        await LazyServiceManager.shared.initializeApp()
                        
                        // Print statistics after initialization
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s delay
                        LazyServiceManager.shared.printStatistics()
                    }
                    
                    // Performance monitoring automatically starts in debug builds
                    #if DEBUG
                    print("⚡ [Performance] Monitoring active - shared instance initialized")
                    #endif
                    
                    // Register Siri Shortcuts / App Intents
                    MyChannelAppShortcuts.updateAppShortcutParameters()

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
                .onChange(of: scenePhase) { _ in
                    print("🎬 [MyChannelApp] ScenePhase changed to \(scenePhase)")
                    
                    // 🔥 LiveTV: Handle app lifecycle for 24/7 channel reliability
                    Task { @MainActor in
                        switch scenePhase {
                        case .active:
                            LiveTVManager.shared.onAppBecameActive()
                            // 🔒 ATT: Request tracking permission (Guideline 5.1.2(i))
                            // Must fire after app is active and first screen is visible.
                            if TrackingTransparencyService.shared.shouldPrompt {
                                _ = await TrackingTransparencyService.shared.requestAuthorization()
                            }
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
                    _ = DeepLinkService.shared.parse(url: url)
                    DeepLinkManager.shared.storeDeferred(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        _ = DeepLinkService.shared.parse(url: url)
                        DeepLinkManager.shared.storeDeferred(url: url)
                    }
                }
        }
    }
    
    private func setupAppearance() {
        // Use adaptive system colors so nav/tab bars automatically switch with dark mode
        let adaptiveBg = UIColor.systemBackground
        let adaptiveLabel = UIColor.label
        let brandRed = UIColor(red: 0.910, green: 0.365, blue: 0.365, alpha: 1) // #E85D5D

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = adaptiveBg
        appearance.titleTextAttributes = [
            .foregroundColor: adaptiveLabel,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: adaptiveLabel,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = brandRed

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = adaptiveBg

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = brandRed

        UITextField.appearance().tintColor = brandRed
        UITextView.appearance().tintColor = brandRed
    }
    
    private func configureAudioSession() {
        struct Once { static var didConfigure = false }
        if Once.didConfigure { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback with no options = exclusive audio, silences other apps.
            // Required for App Store 2.5.4: background audio must be audible to reviewers.
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            Once.didConfigure = true
            print("✅ [MyChannelApp] Audio session configured for background playback")
        } catch {
            print("⚠️ [MyChannelApp] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}