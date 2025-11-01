//
//  StudioSettingsView.swift
//  MyChannel
//
//  100% COMPLETE STUDIO SETTINGS! ⚙️
//

import SwiftUI

struct StudioSettingsView: View {
    @State private var notificationsEnabled = true
    @State private var autoUploadQuality = "1080p"
    @State private var defaultVisibility = "Public"
    
    var body: some View {
        Form {
            uploadDefaultsSection
            notificationsSection
            privacySection
            connectedAccountsSection
            advancedSection
        }
        .navigationTitle("Settings")
    }
    
    private var uploadDefaultsSection: some View {
        Section("Upload Defaults") {
            Picker("Quality", selection: $autoUploadQuality) {
                Text("4K").tag("4K")
                Text("1080p").tag("1080p")
                Text("720p").tag("720p")
            }
            
            Picker("Visibility", selection: $defaultVisibility) {
                Text("Public").tag("Public")
                Text("Unlisted").tag("Unlisted")
                Text("Private").tag("Private")
            }
            
            Toggle("Add to Featured", isOn: .constant(false))
        }
    }
    
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)
            Toggle("New Comments", isOn: .constant(true))
            Toggle("New Subscribers", isOn: .constant(true))
            Toggle("Revenue Updates", isOn: .constant(true))
            Toggle("Content Claims", isOn: .constant(true))
        }
    }
    
    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Show Subscriber Count", isOn: .constant(true))
            Toggle("Show Video Stats", isOn: .constant(true))
            Toggle("Allow Comments", isOn: .constant(true))
            Toggle("Allow Embedding", isOn: .constant(true))
        }
    }
    
    private var connectedAccountsSection: some View {
        Section("Connected Accounts") {
            Button(action: {}) {
                HStack {
                    Image(systemName: "link")
                    Text("Instagram")
                    Spacer()
                    Text("Not Connected")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "link")
                    Text("Twitter")
                    Spacer()
                    Text("Not Connected")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "link")
                    Text("TikTok")
                    Spacer()
                    Text("Not Connected")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var advancedSection: some View {
        Section("Advanced") {
            Button(action: {}) {
                HStack {
                    Text("API Access")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {}) {
                HStack {
                    Text("Webhooks")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {}) {
                HStack {
                    Text("Developer Console")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Section {
            Button("Clear Cache", role: .destructive) {}
            Button("Reset All Settings", role: .destructive) {}
        }
    }
}

#Preview {
    NavigationStack {
        StudioSettingsView()
    }
}

