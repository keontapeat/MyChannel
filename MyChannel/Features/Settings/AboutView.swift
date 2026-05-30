// ⚡ PERFORMANCE: Extracted from SettingsView.swift to its own compilation unit.
// Separate file = independent incremental compilation.
import SwiftUI

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon & Branding
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 15, x: 0, y: 8)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("MyChannel")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, 40)
                    
                    Text("Your Creative Universe Awaits")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 16) {
                        AboutFeatureRow(icon: "video.fill", text: "Upload & share videos")
                        AboutFeatureRow(icon: "play.tv.fill", text: "Stream live content")
                        AboutFeatureRow(icon: "dollarsign.circle.fill", text: "Monetize your creativity")
                        AboutFeatureRow(icon: "person.2.fill", text: "Build your community")
                        AboutFeatureRow(icon: "trophy.fill", text: "Compete & win prizes")
                    }
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://mychannel.live")!) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Visit mychannel.live")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Link(destination: URL(string: "https://twitter.com/mychannelapp")!) {
                            HStack {
                                Image(systemName: "at")
                                Text("@mychannelapp")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text("© 2025 MyChannel, Inc.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("Made with ❤️ in Atlanta")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
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

// MARK: - About Feature Row
struct AboutFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 32)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
    }
}
