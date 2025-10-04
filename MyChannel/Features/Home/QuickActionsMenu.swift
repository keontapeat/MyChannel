//
//  QuickActionsMenu.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct QuickActionsMenu: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingDownloadAlert = false
    @State private var showingReportSheet = false
    @State private var showingBlockConfirmation = false
    @State private var downloadProgress: Double = 0.0
    @State private var isDownloading = false
    
    var body: some View {
        Menu {
            Section("Quick Actions") {
                Button(action: saveVideosToWatchLater) {
                    Label("Save Videos to Watch Later", systemImage: "bookmark.fill")
                }
                
                Button(action: downloadForOffline) {
                    Label("Download for Offline", systemImage: "arrow.down.circle.fill")
                }
                
                Button(action: shareApp) {
                    Label("Share MyChannel", systemImage: "square.and.arrow.up.fill")
                }
            }
            
            Section("Content Management") {
                Button(action: { showingReportSheet = true }) {
                    Label("Report Content", systemImage: "exclamationmark.triangle.fill")
                }
                
                Button(action: markNotInterested) {
                    Label("Not Interested", systemImage: "hand.thumbsdown.fill")
                }
                
                Button(action: refreshFeed) {
                    Label("Refresh Feed", systemImage: "arrow.clockwise")
                }
            }
            
            Section("Creator Actions") {
                Button(action: { showingBlockConfirmation = true }) {
                    Label("Block Creator", systemImage: "person.fill.xmark")
                }
                .foregroundColor(.red)
                
                Button(action: muteCreator) {
                    Label("Mute Creator", systemImage: "speaker.slash.fill")
                }
            }
            
            Section("Settings") {
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
                
                Button(action: clearCache) {
                    Label("Clear Cache", systemImage: "trash.fill")
                }
            }
        } label: {
            Button(action: {}) {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.15), value: false)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .alert("Download Videos", isPresented: $showingDownloadAlert) {
            Button("Download") {
                startDownload()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Download trending videos for offline viewing? This will use your device storage.")
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportContentSheet()
        }
        .alert("Block Creator", isPresented: $showingBlockConfirmation) {
            Button("Block", role: .destructive) {
                blockCreator()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to block this creator? You won't see their content anymore.")
        }
    }
    
    // MARK: - Action Methods
    
    private func saveVideosToWatchLater() {
        let trendingVideos = Video.sampleVideos.filter { $0.viewCount > 100000 }
        var savedCount = 0
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            for video in trendingVideos.prefix(5) {
                if !appState.watchLaterVideos.contains(video.id) {
                    appState.watchLaterVideos.insert(video.id)
                    savedCount += 1
                }
            }
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Show success notification (you can implement a toast system)
        print("✅ Saved \(savedCount) videos to Watch Later")
    }
    
    private func downloadForOffline() {
        showingDownloadAlert = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func startDownload() {
        isDownloading = true
        downloadProgress = 0.0
        
        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.02
            
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                
                // Success haptic
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                print("✅ Download completed!")
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func shareApp() {
        guard let url = URL(string: "https://apps.apple.com/app/mychannel") else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func markNotInterested() {
        // Add logic to mark current feed content as not interested
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("📝 Marked content as not interested")
    }
    
    private func refreshFeed() {
        // Trigger feed refresh
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🔄 Refreshing feed...")
    }
    
    private func blockCreator() {
        // Add logic to block the current creator
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        print("🚫 Creator blocked")
    }
    
    private func muteCreator() {
        // Add logic to mute the current creator
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("🔇 Creator muted")
    }
    
    private func clearCache() {
        // Add logic to clear app cache
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🗑️ Cache cleared")
    }
}

// MARK: - Report Content Sheet
struct ReportContentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason = .spam
    @State private var additionalDetails: String = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why are you reporting this content?")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    VStack(spacing: 12) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            ReportReasonOption(
                                reason: reason,
                                isSelected: selectedReason == reason
                            ) {
                                selectedReason = reason
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Details (Optional)")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Provide more context...", text: $additionalDetails, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.md)
                }
                
                Spacer()
                
                Button("Submit Report") {
                    submitReport()
                    dismiss()
                }
                .font(AppTheme.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.Colors.primary)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
            .padding()
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitReport() {
        // Submit report logic
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("📝 Report submitted: \(selectedReason.rawValue)")
        if !additionalDetails.isEmpty {
            print("📝 Additional details: \(additionalDetails)")
        }
    }
}

// MARK: - Report Reason Option
struct ReportReasonOption: View {
    let reason: ReportReason
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reason.displayName)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(reason.description)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Models
enum ReportReason: String, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case misinformation = "misinformation"
    case copyright = "copyright"
    case inappropriate = "inappropriate"
    case violence = "violence"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment or Bullying"
        case .misinformation: return "Misinformation"
        case .copyright: return "Copyright Infringement"
        case .inappropriate: return "Inappropriate Content"
        case .violence: return "Violence or Harmful Content"
        case .other: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .spam: return "Unwanted or repetitive content"
        case .harassment: return "Content that targets or bullies individuals"
        case .misinformation: return "False or misleading information"
        case .copyright: return "Unauthorized use of copyrighted material"
        case .inappropriate: return "Content not suitable for the platform"
        case .violence: return "Content promoting violence or harm"
        case .other: return "Reason not listed above"
        }
    }
}

#Preview {
    NavigationView {
        VStack {
            Spacer()
            QuickActionsMenu()
                .environmentObject(AppState())
            Spacer()
        }
    }
}