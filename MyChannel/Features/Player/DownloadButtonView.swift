//
//  DownloadButtonView.swift
//  MyChannel
//
//  YouTube Premium-style download button with proper states
//

import SwiftUI

struct DownloadButtonView: View {
    let video: Video
    let action: () -> Void
    
    @StateObject private var premiumService = PremiumService.shared
    @StateObject private var offlineService = OfflineDownloadService.shared
    
    private var downloadState: DownloadState {
        // Check if downloading
        if let download = offlineService.downloads.first(where: { $0.videoId == video.id && $0.status == .downloading }) {
            return .downloading(progress: download.progress)
        }
        
        // Check if downloaded
        if offlineService.isVideoAvailableOffline(video.id) {
            if let download = offlineService.downloads.first(where: { $0.videoId == video.id && $0.status == .completed }) {
                // Check if expired (48 hours like YouTube)
                let expirationDate = download.expiresAt
                let now = Date()
                let timeRemaining = expirationDate.timeIntervalSince(now)
                
                if timeRemaining <= 0 {
                    return .expired
                } else {
                    return .downloaded(expiresAt: expirationDate)
                }
            }
        }
        
        // Check if premium
        if premiumService.isPremium {
            return .available
        } else {
            return .premiumRequired
        }
    }
    
    enum DownloadState: Equatable {
        case available
        case downloading(progress: Double)
        case downloaded(expiresAt: Date)
        case expired
        case premiumRequired
        
        static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
            switch (lhs, rhs) {
            case (.available, .available):
                return true
            case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
                return lhsProgress == rhsProgress
            case (.downloaded(let lhsDate), .downloaded(let rhsDate)):
                return lhsDate == rhsDate
            case (.expired, .expired):
                return true
            case (.premiumRequired, .premiumRequired):
                return true
            default:
                return false
            }
        }
    }
    
    @State private var isPressed: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Background with subtle glow
                    Circle()
                        .fill(backgroundFill)
                        .frame(width: 48, height: 48)
                        .shadow(
                            color: shadowColor,
                            radius: shadowRadius,
                            x: 0,
                            y: 2
                        )
                        .scaleEffect(pulseScale * (isPressed ? 0.95 : 1.0))
                    
                    // Icon
                    downloadIcon
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    // Progress indicator for downloading
                    if case .downloading(let progress) = downloadState {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(iconColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 48, height: 48)
                    }
                    
                    // Premium indicator
                    if downloadState == .premiumRequired {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                    .offset(x: 6, y: -6)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Title with progress if downloading
                VStack(spacing: 2) {
                    Text(downloadTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    if case .downloading(let progress) = downloadState {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            if case .downloading = downloadState {
                startPulseAnimation()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(downloadTitle) button")
    }
    
    private var backgroundFill: Color {
        switch downloadState {
        case .available:
            return AppTheme.Colors.surface.opacity(0.8)
        case .downloading:
            return Color.blue.opacity(0.15)
        case .downloaded:
            return Color.green.opacity(0.15)
        case .expired:
            return Color.orange.opacity(0.15)
        case .premiumRequired:
            return AppTheme.Colors.surface.opacity(0.8)
        }
    }
    
    private var shadowColor: Color {
        switch downloadState {
        case .available:
            return AppTheme.Colors.surface.opacity(0.2)
        case .downloading:
            return Color.blue.opacity(0.3)
        case .downloaded:
            return Color.green.opacity(0.3)
        case .expired:
            return Color.orange.opacity(0.3)
        case .premiumRequired:
            return AppTheme.Colors.surface.opacity(0.2)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch downloadState {
        case .available, .premiumRequired:
            return 4
        case .downloading, .downloaded, .expired:
            return 8
        }
    }
    
    private var iconColor: Color {
        switch downloadState {
        case .available:
            return AppTheme.Colors.textSecondary
        case .downloading:
            return .blue
        case .downloaded:
            return .green
        case .expired:
            return .orange
        case .premiumRequired:
            return AppTheme.Colors.textSecondary
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }
    }
    
    @ViewBuilder
    private var downloadIcon: some View {
        switch downloadState {
        case .available:
            Image(systemName: "arrow.down.circle")
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
        case .expired:
            Image(systemName: "arrow.clockwise.circle")
        case .premiumRequired:
            Image(systemName: "arrow.down.circle")
        }
    }
    
    private var downloadTitle: String {
        switch downloadState {
        case .available:
            return "Download"
        case .downloading(let progress):
            return "Downloading"
        case .downloaded:
            return "Downloaded"
        case .expired:
            return "Expired"
        case .premiumRequired:
            return "Download"
        }
    }
    
    private var downloadColor: Color {
        switch downloadState {
        case .available:
            return AppTheme.Colors.textSecondary
        case .downloading:
            return .blue
        case .downloaded:
            return .green
        case .expired:
            return .orange
        case .premiumRequired:
            return AppTheme.Colors.textSecondary
        }
    }
}

