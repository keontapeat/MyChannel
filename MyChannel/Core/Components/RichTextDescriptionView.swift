//
//  RichTextDescriptionView.swift
//  MyChannel
//
//  YouTube Parity: Rich text description with clickable links, timestamps, @mentions, and #hashtags
//  Created for MyChannel by AI Assistant
//

import SwiftUI

/// Parses and displays video descriptions with clickable links, timestamps, @channel mentions, and #hashtags
struct RichTextDescriptionView: View {
    let description: String
    let onLinkTap: ((URL) -> Void)?
    let onTimestampTap: ((TimeInterval) -> Void)?
    let onChannelTap: ((String) -> Void)?
    let onHashtagTap: ((String) -> Void)?
    
    init(
        description: String,
        onLinkTap: ((URL) -> Void)? = nil,
        onTimestampTap: ((TimeInterval) -> Void)? = nil,
        onChannelTap: ((String) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil
    ) {
        self.description = description
        self.onLinkTap = onLinkTap
        self.onTimestampTap = onTimestampTap
        self.onChannelTap = onChannelTap
        self.onHashtagTap = onHashtagTap
    }
    
    var body: some View {
        parseAndDisplayDescription()
    }
    
    @ViewBuilder
    private func parseAndDisplayDescription() -> some View {
        let segments = parseDescription(description)
        
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                switch segment.type {
                case .link:
                    if let url = segment.url {
                        Button(action: {
                            onLinkTap?(url)
                        }) {
                            Text(segment.text)
                                .foregroundColor(AppTheme.Colors.primary)
                                .fontWeight(.medium)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(segment.text)
                            .foregroundColor(AppTheme.Colors.primary)
                            .fontWeight(.medium)
                    }
                    
                case .timestamp:
                    if let time = segment.timestamp {
                        Button(action: {
                            onTimestampTap?(time)
                        }) {
                            Text(segment.text)
                                .foregroundColor(AppTheme.Colors.primary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(segment.text)
                            .foregroundColor(AppTheme.Colors.primary)
                            .fontWeight(.medium)
                    }
                    
                case .channel:
                    if let value = segment.value {
                        Button(action: {
                            onChannelTap?(value)
                        }) {
                            Text(segment.text)
                                .foregroundColor(.red)  // 🔥 YOUTUBE PARITY: Red for @channel
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(segment.text)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                    
                case .hashtag:
                    if let value = segment.value {
                        Button(action: {
                            onHashtagTap?(value)
                        }) {
                            Text(segment.text)
                                .foregroundColor(AppTheme.Colors.primary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(segment.text)
                            .foregroundColor(AppTheme.Colors.primary)
                            .fontWeight(.medium)
                    }
                    
                case .plain:
                    Text(segment.text)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Parsing Logic
    
    private func parseDescription(_ description: String) -> [DescriptionSegment] {
        var segments: [DescriptionSegment] = []
        var currentIndex = description.startIndex
        
        // Regex patterns
        let urlPattern = #"https?://[^\s]+"#  // URLs
        let timestampPattern = #"(\d{1,2}):(\d{2})(?::(\d{2}))?"#  // Timestamps: 1:23 or 1:23:45
        let channelPattern = #"@([a-zA-Z0-9_.-]+)"#  // @channel
        let hashtagPattern = #"#([a-zA-Z0-9_]+)"#  // #hashtag
        
        // Find all matches
        var matches: [(range: Range<String.Index>, type: DescriptionSegmentType, value: String?, url: URL?, timestamp: TimeInterval?)] = []
        
        // Find URLs
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let nsString = description as NSString
            let results = urlRegex.matches(in: description, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: description),
                   let url = URL(string: String(description[range])) {
                    matches.append((range: range, type: .link, value: nil, url: url, timestamp: nil))
                }
            }
        }
        
        // Find timestamps
        if let timestampRegex = try? NSRegularExpression(pattern: timestampPattern, options: []) {
            let nsString = description as NSString
            let results = timestampRegex.matches(in: description, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: description) {
                    let timestampText = String(description[range])
                    if let time = parseTimestamp(timestampText) {
                        matches.append((range: range, type: .timestamp, value: nil, url: nil, timestamp: time))
                    }
                }
            }
        }
        
        // Find @channel mentions
        if let channelRegex = try? NSRegularExpression(pattern: channelPattern, options: []) {
            let nsString = description as NSString
            let results = channelRegex.matches(in: description, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: description) {
                    let value = String(description[range].dropFirst()) // Remove @
                    matches.append((range: range, type: .channel, value: value, url: nil, timestamp: nil))
                }
            }
        }
        
        // Find #hashtags
        if let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let nsString = description as NSString
            let results = hashtagRegex.matches(in: description, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: description) {
                    let value = String(description[range].dropFirst()) // Remove #
                    matches.append((range: range, type: .hashtag, value: value, url: nil, timestamp: nil))
                }
            }
        }
        
        // Sort matches by position
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build segments
        for match in matches {
            // Add plain text before match
            if currentIndex < match.range.lowerBound {
                let plainText = String(description[currentIndex..<match.range.lowerBound])
                if !plainText.isEmpty {
                    segments.append(DescriptionSegment(text: plainText, type: .plain))
                }
            }
            
            // Add the match
            let matchText = String(description[match.range])
            segments.append(DescriptionSegment(
                text: matchText,
                type: match.type,
                value: match.value,
                url: match.url,
                timestamp: match.timestamp
            ))
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining plain text
        if currentIndex < description.endIndex {
            let plainText = String(description[currentIndex...])
            if !plainText.isEmpty {
                segments.append(DescriptionSegment(text: plainText, type: .plain))
            }
        }
        
        // If no matches, return entire description as plain
        if segments.isEmpty {
            segments.append(DescriptionSegment(text: description, type: .plain))
        }
        
        return segments
    }
    
    private func parseTimestamp(_ text: String) -> TimeInterval? {
        // Parse formats: "1:23" or "1:23:45"
        let components = text.split(separator: ":").compactMap { Int($0) }
        
        if components.count == 2 {
            // MM:SS format
            return TimeInterval(components[0] * 60 + components[1])
        } else if components.count == 3 {
            // HH:MM:SS format
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct DescriptionSegment {
    let text: String
    let type: DescriptionSegmentType
    let value: String?  // For @channel or #hashtag
    let url: URL?  // For links
    let timestamp: TimeInterval?  // For timestamps
    
    init(text: String, type: DescriptionSegmentType, value: String? = nil, url: URL? = nil, timestamp: TimeInterval? = nil) {
        self.text = text
        self.type = type
        self.value = value
        self.url = url
        self.timestamp = timestamp
    }
}

enum DescriptionSegmentType {
    case plain
    case link
    case timestamp
    case channel
    case hashtag
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        RichTextDescriptionView(
            description: "Check out this video! Visit https://example.com for more info. Watch at 1:23 for the best part. Thanks to @CreatorName and @AnotherCreator! #Gaming #Tech",
            onLinkTap: { url in
                print("Tapped link: \(url)")
            },
            onTimestampTap: { time in
                print("Tapped timestamp: \(time)s")
            },
            onChannelTap: { channel in
                print("Tapped channel: \(channel)")
            },
            onHashtagTap: { hashtag in
                print("Tapped hashtag: \(hashtag)")
            }
        )
        .padding()
    }
    .background(AppTheme.Colors.background)
}

