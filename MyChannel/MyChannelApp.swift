//
//  MyChannelApp.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

@main
struct MyChannelApp: App {
    // Use lazy initialization to prevent circular dependencies
    @StateObject private var authManager: AuthenticationManager = {
        print("🔐 Initializing AuthenticationManager...")
        return AuthenticationManager.shared
    }()
    
    init() {
        print("🚀 MyChannelApp init started...")
        
        // Configure app appearance
        setupAppearance()
        
        print("✅ MyChannelApp init completed")
    }
    
    var body: some Scene {
        WindowGroup {
            // SPLASH SCREEN WITH MAINTABVIEW CONNECTION
            SplashContainer()
                .environmentObject(authManager)
                .preferredColorScheme(.light)
                .onAppear {
                    print("📱 App appeared with MC logo splash!")
                }
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