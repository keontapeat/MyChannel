//
//  VideoQuality.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

// MARK: - Video Quality Model
enum VideoQuality: String, Codable, CaseIterable, CustomStringConvertible {
    case quality144p = "144p"
    case quality240p = "240p"
    case quality360p = "360p" 
    case quality480p = "480p"
    case quality720p = "720p"
    case quality1080p = "1080p"
    case quality1440p = "1440p"
    case quality2160p = "2160p" // 4K
    case quality4320p = "4320p" // 8K
    case auto = "auto"
    
    var description: String {
        return displayName
    }
    
    var displayName: String {
        switch self {
        case .quality144p: return "144p"
        case .quality240p: return "240p"
        case .quality360p: return "360p"
        case .quality480p: return "480p"
        case .quality720p: return "720p HD"
        case .quality1080p: return "1080p Full HD"
        case .quality1440p: return "1440p 2K"
        case .quality2160p: return "2160p 4K"
        case .quality4320p: return "4320p 8K"
        case .auto: return "Auto"
        }
    }
    
    var resolution: CGSize {
        switch self {
        case .quality144p: return CGSize(width: 256, height: 144)
        case .quality240p: return CGSize(width: 426, height: 240)
        case .quality360p: return CGSize(width: 640, height: 360)
        case .quality480p: return CGSize(width: 854, height: 480)
        case .quality720p: return CGSize(width: 1280, height: 720)
        case .quality1080p: return CGSize(width: 1920, height: 1080)
        case .quality1440p: return CGSize(width: 2560, height: 1440)
        case .quality2160p: return CGSize(width: 3840, height: 2160)
        case .quality4320p: return CGSize(width: 7680, height: 4320)
        case .auto: return CGSize(width: 1920, height: 1080) // Default
        }
    }
    
    var bitrate: Int {
        switch self {
        case .quality144p: return 100_000 // 100 kbps
        case .quality240p: return 300_000 // 300 kbps
        case .quality360p: return 700_000 // 700 kbps
        case .quality480p: return 1_500_000 // 1.5 Mbps
        case .quality720p: return 5_000_000 // 5 Mbps
        case .quality1080p: return 8_000_000 // 8 Mbps
        case .quality1440p: return 16_000_000 // 16 Mbps
        case .quality2160p: return 35_000_000 // 35 Mbps
        case .quality4320p: return 100_000_000 // 100 Mbps
        case .auto: return 8_000_000 // Default to 1080p
        }
    }
    
    var isHD: Bool {
        switch self {
        case .quality720p, .quality1080p, .quality1440p, .quality2160p, .quality4320p:
            return true
        default:
            return false
        }
    }
    
    var is4K: Bool {
        return self == .quality2160p || self == .quality4320p
    }
    
    var iconName: String {
        if is4K {
            return "4k.tv"
        } else if isHD {
            return "tv.and.hifispeaker.fill"
        } else {
            return "tv"
        }
    }
    
    var color: Color {
        switch self {
        case .quality144p, .quality240p: return .red
        case .quality360p, .quality480p: return .orange
        case .quality720p: return .blue
        case .quality1080p: return .green
        case .quality1440p: return .purple
        case .quality2160p, .quality4320p: return .pink
        case .auto: return .primary
        }
    }
    
    // For sorting from lowest to highest quality
    var sortOrder: Int {
        switch self {
        case .quality144p: return 0
        case .quality240p: return 1
        case .quality360p: return 2
        case .quality480p: return 3
        case .quality720p: return 4
        case .quality1080p: return 5
        case .quality1440p: return 6
        case .quality2160p: return 7
        case .quality4320p: return 8
        case .auto: return 9
        }
    }
}

// MARK: - Video Quality Extensions
extension VideoQuality {
    static var recommendedQualities: [VideoQuality] {
        return [.quality360p, .quality720p, .quality1080p, .auto]
    }
    
    static var allQualitiesSorted: [VideoQuality] {
        return VideoQuality.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func canPlayOn(device: UIUserInterfaceIdiom) -> Bool {
        switch device {
        case .phone:
            // iPhones can handle up to 4K
            return sortOrder <= VideoQuality.quality2160p.sortOrder
        case .pad:
            // iPads can handle all qualities
            return true
        case .tv:
            // Apple TV can handle all qualities
            return true
        default:
            // Conservative approach for other devices
            return sortOrder <= VideoQuality.quality1080p.sortOrder
        }
    }
    
    func estimatedDataUsage(for duration: TimeInterval) -> Double {
        // Returns estimated data usage in MB
        let bitsPerSecond = Double(bitrate)
        let bytesPerSecond = bitsPerSecond / 8
        let totalBytes = bytesPerSecond * duration
        return totalBytes / (1024 * 1024) // Convert to MB
    }
}

#Preview("Video Quality Demo") {
    VStack(spacing: 16) {
        Text("Video Quality Options")
            .font(AppTheme.Typography.largeTitle)
        
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(VideoQuality.allQualitiesSorted, id: \.self) { quality in
                HStack(spacing: 8) {
                    Image(systemName: quality.iconName)
                        .foregroundColor(quality.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quality.displayName)
                            .font(AppTheme.Typography.body)
                            .fontWeight(.medium)
                        
                        Text("\(Int(quality.resolution.width))x\(Int(quality.resolution.height))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Usage Estimation")
                .font(AppTheme.Typography.headline)
            
            Text("For a 10-minute video:")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            ForEach([VideoQuality.quality360p, .quality720p, .quality1080p, .quality2160p], id: \.self) { quality in
                HStack {
                    Text(quality.displayName)
                        .font(AppTheme.Typography.body)
                    
                    Spacer()
                    
                    Text("\(Int(quality.estimatedDataUsage(for: 600))) MB")
                        .font(AppTheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(quality.color)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
        
        Spacer()
    }
    .padding()
    .background(AppTheme.Colors.background)
}