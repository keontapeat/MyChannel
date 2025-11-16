//
//  PlaybackSettingsView.swift
//  MyChannel
//
//  🔥 NUCLEAR FIX #2: Playback settings including Auto-PiP
//

import SwiftUI

struct PlaybackSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List {
            // 🔥 NUCLEAR FIX #2: Auto-PiP Toggle
            Section {
                Toggle(isOn: $appState.autoPiPEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "pip")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("Auto Picture-in-Picture")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Text("Automatically start mini player in Picture-in-Picture mode")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .tint(AppTheme.Colors.primary)
            } header: {
                Text("Picture-in-Picture")
            } footer: {
                Text("When enabled, videos will automatically enter Picture-in-Picture mode when you minimize the player. This allows you to watch videos while using other apps.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Auto-play Section
            Section {
                Toggle(isOn: $appState.autoPlayEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("Autoplay")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Text("Play next video automatically")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .tint(AppTheme.Colors.primary)
            } header: {
                Text("Autoplay")
            } footer: {
                Text("When a video ends, the next video will start playing automatically.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        PlaybackSettingsView()
            .environmentObject(AppState.shared)
    }
}

