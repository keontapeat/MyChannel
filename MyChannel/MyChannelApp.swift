//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

@main
struct MyChannelApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var networkService = NetworkService.shared
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    init() {
        // Print app configuration on startup
        AppConfig.printConfiguration()
        
        // Configure app appearance
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(networkService)
                        .environmentObject(databaseService)
                        .withNotifications()
                } else {
                    AuthenticationView()
                        .environmentObject(authManager)
                        .withNotifications()
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                setupServices()
            }
        }
    }
    
    private func setupServices() {
        // Setup notifications if needed
        if AppConfig.Features.enablePushNotifications {
            notificationManager.requestPermission()
        }
        
        // Track app launch
        Task {
            await AnalyticsService.shared.trackAppLaunchTime(1.0) // Mock launch time
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
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
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.background)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure other UI elements
        UITextField.appearance().tintColor = UIColor(AppTheme.Colors.primary)
        UITextView.appearance().tintColor = UIColor(AppTheme.Colors.primary)
    }
}