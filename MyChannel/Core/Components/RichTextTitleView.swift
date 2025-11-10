//
//  RichTextTitleView.swift
//  MyChannel
//
//  YouTube Parity: Channel tagging (@channel) and hashtags (#tag) in video titles
//  Created for MyChannel by AI Assistant
//

import SwiftUI

/// Parses and displays video titles with clickable @channel mentions and #hashtags
struct RichTextTitleView: View {
    let title: String
    let onChannelTap: ((String) -> Void)?
    let onHashtagTap: ((String) -> Void)?
    
    @State private var parsedSegments: [TextSegment] = []
    
    init(
        title: String,
        onChannelTap: ((String) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil
    ) {
        self.title = title
        self.onChannelTap = onChannelTap
        self.onHashtagTap = onHashtagTap
    }
    
    var body: some View {
        Text(attributedString)
            .lineLimit(nil)
    }
    
    private var attributedString: AttributedString {
        var result = AttributedString("")
        
        // Parse the title into segments
        let segments = parseTitle(title)
        
        for segment in segments {
            var attributedSegment = AttributedString(segment.text)
            
            switch segment.type {
            case .channel:
                attributedSegment.foregroundColor = .red  // 🔥 YOUTUBE PARITY: Red color for @channel tags
                attributedSegment.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)
                // Make it tappable (SwiftUI will handle tap gestures)
                
            case .hashtag:
                attributedSegment.foregroundColor = AppTheme.Colors.primary
                attributedSegment.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)
                
            case .plain:
                attributedSegment.foregroundColor = AppTheme.Colors.textPrimary
            }
            
            result.append(attributedSegment)
        }
        
        return result
    }
    
    // MARK: - Parsing Logic
    
    private func parseTitle(_ title: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = title.startIndex
        
        // Regex patterns - support usernames with underscores, dots, etc.
        let channelPattern = #"@([a-zA-Z0-9_.-]+)"#  // 🔥 FIX: Support more username characters
        let hashtagPattern = #"#([a-zA-Z0-9_]+)"#
        
        // Find all matches
        var matches: [(range: Range<String.Index>, type: SegmentType, value: String)] = []
        
        // Find @channel mentions
        if let channelRegex = try? NSRegularExpression(pattern: channelPattern, options: []) {
            let nsString = title as NSString
            let results = channelRegex.matches(in: title, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: title) {
                    let value = String(title[range].dropFirst()) // Remove @
                    matches.append((range: range, type: .channel, value: value))
                }
            }
        }
        
        // Find #hashtags
        if let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let nsString = title as NSString
            let results = hashtagRegex.matches(in: title, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: title) {
                    let value = String(title[range].dropFirst()) // Remove #
                    matches.append((range: range, type: .hashtag, value: value))
                }
            }
        }
        
        // Sort matches by position
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build segments
        for match in matches {
            // Add plain text before match
            if currentIndex < match.range.lowerBound {
                let plainText = String(title[currentIndex..<match.range.lowerBound])
                if !plainText.isEmpty {
                    segments.append(TextSegment(text: plainText, type: .plain))
                }
            }
            
            // Add the match
            let matchText = String(title[match.range])
            segments.append(TextSegment(text: matchText, type: match.type, value: match.value))
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining plain text
        if currentIndex < title.endIndex {
            let plainText = String(title[currentIndex...])
            if !plainText.isEmpty {
                segments.append(TextSegment(text: plainText, type: .plain))
            }
        }
        
        // If no matches, return entire title as plain
        if segments.isEmpty {
            segments.append(TextSegment(text: title, type: .plain))
        }
        
        return segments
    }
}

// MARK: - Supporting Types

private enum SegmentType {
    case plain
    case channel
    case hashtag
}

private struct TextSegment {
    let text: String
    let type: SegmentType
    var value: String? = nil
}

// MARK: - Interactive Version (for tap handling)

struct InteractiveRichTextTitleView: View {
    let title: String
    let onChannelTap: ((String) -> Void)?
    let onHashtagTap: ((String) -> Void)?
    let textColor: Color?  // 🔥 FIX: Allow custom text color for dark backgrounds
    
    init(
        title: String,
        onChannelTap: ((String) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil,
        textColor: Color? = nil
    ) {
        self.title = title
        self.onChannelTap = onChannelTap
        self.onHashtagTap = onHashtagTap
        self.textColor = textColor
    }
    
    var body: some View {
        parseAndDisplayTitle()
    }
    
    @ViewBuilder
    private func parseAndDisplayTitle() -> some View {
        let segments = parseTitle(title)
        
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                switch segment.type {
                case .channel:
                    if let value = segment.value {
                        Button(action: {
                            onChannelTap?(value)
                        }) {
                            Text(segment.text)
                                .foregroundColor(.red)  // 🔥 YOUTUBE PARITY: Red color for @channel tags
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(segment.text)
                            .foregroundColor(.red)  // 🔥 YOUTUBE PARITY: Red color for @channel tags
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
                        .foregroundColor(textColor ?? AppTheme.Colors.textPrimary)  // 🔥 FIX: Use custom color if provided
                }
            }
        }
    }
    
    private func parseTitle(_ title: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = title.startIndex
        
        // Regex patterns - support usernames with underscores, dots, etc.
        let channelPattern = #"@([a-zA-Z0-9_.-]+)"#  // 🔥 FIX: Support more username characters
        let hashtagPattern = #"#([a-zA-Z0-9_]+)"#
        
        // Find all matches
        var matches: [(range: Range<String.Index>, type: SegmentType, value: String)] = []
        
        // Find @channel mentions
        if let channelRegex = try? NSRegularExpression(pattern: channelPattern, options: []) {
            let nsString = title as NSString
            let results = channelRegex.matches(in: title, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: title) {
                    let value = String(title[range].dropFirst()) // Remove @
                    matches.append((range: range, type: .channel, value: value))
                }
            }
        }
        
        // Find #hashtags
        if let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let nsString = title as NSString
            let results = hashtagRegex.matches(in: title, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: title) {
                    let value = String(title[range].dropFirst()) // Remove #
                    matches.append((range: range, type: .hashtag, value: value))
                }
            }
        }
        
        // Sort matches by position
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build segments
        for match in matches {
            // Add plain text before match
            if currentIndex < match.range.lowerBound {
                let plainText = String(title[currentIndex..<match.range.lowerBound])
                if !plainText.isEmpty {
                    segments.append(TextSegment(text: plainText, type: .plain))
                }
            }
            
            // Add the match
            let matchText = String(title[match.range])
            segments.append(TextSegment(text: matchText, type: match.type, value: match.value))
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining plain text
        if currentIndex < title.endIndex {
            let plainText = String(title[currentIndex...])
            if !plainText.isEmpty {
                segments.append(TextSegment(text: plainText, type: .plain))
            }
        }
        
        // If no matches, return entire title as plain
        if segments.isEmpty {
            segments.append(TextSegment(text: title, type: .plain))
        }
        
        return segments
    }
}

#Preview {
    VStack(spacing: 20) {
        InteractiveRichTextTitleView(
            title: "WayP - Leave (Remix) Official Music Video @ShotByKeonta #MusicVideo #Remix",
            onChannelTap: { channel in
                print("Tapped channel: \(channel)")
            },
            onHashtagTap: { hashtag in
                print("Tapped hashtag: \(hashtag)")
            }
        )
        .padding()
        
        InteractiveRichTextTitleView(
            title: "Check out @CreatorName and @AnotherCreator in this #Gaming video!",
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

