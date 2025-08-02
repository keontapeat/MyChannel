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
    
    @StateObject private var networkService: NetworkService = {
        print("🌐 Initializing NetworkService...")
        return NetworkService.shared
    }()
    
    @StateObject private var databaseService: DatabaseService = {
        print("💾 Initializing DatabaseService...")
        return DatabaseService.shared
    }()
    
    @StateObject private var notificationManager: NotificationManager = {
        print("🔔 Initializing NotificationManager...")
        return NotificationManager.shared
    }()
    
    init() {
        print("🚀 MyChannelApp init started...")
        
        // Print app configuration on startup
        do {
            AppConfig.printConfiguration()
        } catch {
            print("❌ Failed to print app configuration: \(error)")
        }
        
        // Configure app appearance
        do {
            setupAppearance()
        } catch {
            print("❌ Failed to setup appearance: \(error)")
        }
        
        print("✅ MyChannelApp init completed")
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
                print("📱 App appeared, setting up services...")
                setupServices()
            }
            .onOpenURL { url in
                print("🔗 App opened with URL: \(url)")
            }
        }
    }
    
    private func setupServices() {
        print("⚙️ Setting up services...")
        
        // Setup global error handling
        NSSetUncaughtExceptionHandler { exception in
            print("💥 UNCAUGHT EXCEPTION: \(exception)")
            print("💥 Call stack: \(exception.callStackSymbols)")
        }
        
        // Setup notifications if needed
        if AppConfig.Features.enablePushNotifications {
            print("🔔 Requesting notification permissions...")
            notificationManager.requestPermission()
        }
        
        // Safely track app launch with error handling
        Task {
            do {
                print("📊 Tracking app launch...")
                await AnalyticsService.shared.trackAppLaunchTime(1.0)
                print("✅ App launch tracking completed")
            } catch {
                print("❌ Analytics tracking failed: \(error)")
            }
        }
        
        print("✅ Services setup completed")
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