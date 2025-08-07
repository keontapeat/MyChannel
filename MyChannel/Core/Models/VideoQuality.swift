//
//  VideoQuality.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Video Quality Enum
enum VideoQuality: String, CaseIterable, Codable {
    case auto = "Auto"
    case quality144p = "144p"
    case quality240p = "240p"
    case quality360p = "360p"
    case quality480p = "480p"
    case quality720p = "720p"
    case quality1080p = "1080p"
    case quality1440p = "1440p"
    case quality2160p = "4K"
    case quality4K = "4K_Ultra"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .quality144p: return "144p"
        case .quality240p: return "240p"
        case .quality360p: return "360p"
        case .quality480p: return "480p"
        case .quality720p: return "720p"
        case .quality1080p: return "1080p"
        case .quality1440p: return "1440p"
        case .quality2160p: return "4K"
        case .quality4K: return "4K Ultra"
        }
    }
    
    var resolution: (width: Int, height: Int) {
        switch self {
        case .auto: return (1920, 1080) // Default to 1080p for auto
        case .quality144p: return (256, 144)
        case .quality240p: return (426, 240)
        case .quality360p: return (640, 360)
        case .quality480p: return (854, 480)
        case .quality720p: return (1280, 720)
        case .quality1080p: return (1920, 1080)
        case .quality1440p: return (2560, 1440)
        case .quality2160p: return (3840, 2160)
        case .quality4K: return (3840, 2160)
        }
    }
    
    var bitrate: Int {
        switch self {
        case .auto: return 5000 // Default bitrate for auto
        case .quality144p: return 200
        case .quality240p: return 500
        case .quality360p: return 1000
        case .quality480p: return 2000
        case .quality720p: return 3000
        case .quality1080p: return 5000
        case .quality1440p: return 8000
        case .quality2160p: return 15000
        case .quality4K: return 25000
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Video Quality Options")
            .font(.title)
            .fontWeight(.bold)
        
        ForEach(VideoQuality.allCases, id: \.self) { quality in
            HStack {
                Text(quality.displayName)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(quality.resolution.width) × \(quality.resolution.height)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(quality.bitrate) kbps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    .padding()
}