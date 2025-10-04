//
//  SettingsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var autoplayEnabled = true
    @State private var qualityPreference: PlaybackQuality = .auto
    @State private var downloadQuality: PlaybackQuality = .medium
    @State private var showingAbout = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Playback") {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Toggle("Autoplay Videos", isOn: $autoplayEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Picker("Video Quality", selection: $qualityPreference) {
                            ForEach(PlaybackQuality.allCases, id: \.self) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                    }
                }
                
                Section("Downloads") {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Picker("Download Quality", selection: $downloadQuality) {
                            ForEach(PlaybackQuality.allCases.filter { $0 != .auto }, id: \.self) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                    }
                }
                
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Toggle("Push Notifications", isOn: $notificationsEnabled)
                    }
                }
                
                Section("About") {
                    Button("About MyChannel") {
                        showingAbout = true
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Button("Terms of Service") {
                        // Open terms
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image("MyChannel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                    
                    Text("MyChannel")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built with SwiftUI")
                    Text("Designed for iOS 17+")
                    Text("Made with ❤️ by Keonta")
                }
                .font(.body)
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Models
enum PlaybackQuality: String, CaseIterable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low (360p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .ultra: return "Ultra (4K)"
        }
    }
}

#Preview {
    SettingsView()
}