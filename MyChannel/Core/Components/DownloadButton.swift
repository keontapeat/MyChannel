//
//  DownloadButton.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct DownloadButton: View {
    let video: Video
    let size: DownloadButtonSize
    @StateObject private var premiumService = PremiumService.shared
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPremiumAlert = false
    
    var isDownloaded: Bool {
        premiumService.isVideoDownloaded(video.id)
    }
    
    var currentDownloadProgress: Double? {
        premiumService.getDownloadProgress(for: video.id)
    }
    
    var buttonSize: CGFloat {
        switch size {
        case .small: return 24
        case .medium: return 32
        case .large: return 44
        }
    }
    
    var body: some View {
        ZStack {
            if let progress = currentDownloadProgress, progress < 1.0 {
                // Download in progress
                CircularProgressView(progress: progress, size: buttonSize)
            } else if isDownloaded {
                // Already downloaded
                Button(action: {
                    handleDownloadAction()
                }) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: buttonSize, weight: .bold))
                        .foregroundColor(AppTheme.Colors.success)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Not downloaded
                Button(action: {
                    handleDownloadAction()
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: buttonSize, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Premium Required", isPresented: $showPremiumAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Get Premium") {
                // Navigate to premium subscription view
                NotificationCenter.default.post(name: .navigateToPremium, object: nil)
            }
        } message: {
            Text("Offline downloads are only available with a MyChannel Premium subscription.")
        }
    }
    
    private func handleDownloadAction() {
        if isDownloaded {
            // Already downloaded - could show options like "Delete" or "Play Offline"
            print("Video already downloaded: \(video.title)")
            // In a real app, this would navigate to the offline player
        } else {
            // Start download
            startDownload()
        }
    }
    
    private func startDownload() {
        // Check if user has premium
        guard premiumService.isPremium else {
            showPremiumAlert = true
            return
        }
        
        // Check if user has offline downloads feature
        guard premiumService.hasFeature(.offlineDownloads) else {
            errorMessage = "Your current plan doesn't include offline downloads."
            showError = true
            return
        }
        
        Task {
            do {
                try await premiumService.downloadVideo(video)
            } catch PremiumError.alreadyDownloaded {
                // This shouldn't happen due to our checks, but just in case
                print("Video already downloaded")
            } catch PremiumError.downloadLimitReached {
                errorMessage = "You've reached your download limit for your current plan."
                showError = true
            } catch PremiumError.featureNotAvailable {
                errorMessage = "Offline downloads are not available in your current plan."
                showError = true
            } catch {
                errorMessage = "An error occurred while downloading: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    AppTheme.Colors.textTertiary.opacity(0.3),
                    lineWidth: size * 0.1
                )
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    AppTheme.Colors.primary,
                    style: StrokeStyle(
                        lineWidth: size * 0.1,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.2), value: progress)
            
            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Download Button Size
enum DownloadButtonSize {
    case small  // 24pt
    case medium // 32pt
    case large  // 44pt
}

// MARK: - Notification for Navigation
extension Notification.Name {
    static let navigateToPremium = Notification.Name("navigateToPremium")
}
