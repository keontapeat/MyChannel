//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import UserNotifications

@main
struct MyChannelApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) var firebaseDelegate

    @StateObject private var authManager: AuthenticationManager = AuthenticationManager.shared
    @StateObject private var appState: AppState = AppState()
    
    init() {
        print("🚀 MyChannelApp init started...")
        setupAppearance()
        print("✅ MyChannelApp init completed")
    }
    
    var body: some Scene {
        WindowGroup {
            SplashContainer()
                .environmentObject(authManager)
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .onAppear {
                    print("📱 App appeared with MC logo splash!")
                    Task {
                        _ = await PushNotificationService.shared.getAuthorizationStatus()
                    }
                }
                .onOpenURL { url in
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