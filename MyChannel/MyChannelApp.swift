//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UserNotifications

@main
struct MyChannelApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) var firebaseDelegate

    @StateObject private var authManager: AuthenticationManager = AuthenticationManager.shared
    @StateObject private var appState: AppState = AppState()
    
    init() {
        print("🚀 MyChannelApp init started...")
        
        // Configure Firebase as early as possible to avoid startup warnings
        FirebaseManager.shared.configureIfPossible()
        setupAppearance()
        
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
    
    var body: some Scene {
        WindowGroup {
            SplashContainer()
                .environmentObject(authManager)
                .environmentObject(appState)
                .onAppear {
                    print("📱 App appeared with MC logo splash!")
                    
                    // 🏥 Start MyChannel Doctor 24/7 monitoring
                    MyChannelDoctorService.shared.startMonitoring()
                    
                    // Start performance optimization after UI is ready
                    PerformanceOptimizer.shared.optimizeAppLaunch()
                    
                    // Start performance monitoring in debug builds
                    #if DEBUG
                    Task {
                        await PerformanceMonitor.shared.startMonitoring()
                    }
                    #endif
                    
                    // 🔥 INITIALIZE SMART USER SEEDER: Populate app with AI-generated users
                    Task {
                        await SmartUserSeederService.shared.initialize()
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
}