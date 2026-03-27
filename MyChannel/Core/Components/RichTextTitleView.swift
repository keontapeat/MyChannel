//
//  RichTextTitleView.swift
//  MyChannel
//
//  YouTube Parity: Channel tagging (@channel) and hashtags (#tag) in video titles
//  🔥 YOUTUBE PARITY: Display @ChannelName (displayName) instead of @username
//  Created for MyChannel by AI Assistant
//

import SwiftUI

/// 🔥 YOUTUBE PARITY: Maps usernames to display names for @mentions
/// When a creator tags a channel, we show the channel name not the username
/// Example: @sbkeonta_ → @ShotByKeonta
struct ChannelMentionMapper {
    /// Maps username to display name for known channels
    /// This is populated from video.creator and any tagged users
    private var usernameToDisplayName: [String: String] = [:]
    
    init(creator: User? = nil, taggedUsers: [User] = []) {
        // Add creator mapping
        if let creator = creator {
            usernameToDisplayName[creator.username.lowercased()] = creator.displayName
        }
        
        // Add tagged users mappings
        for user in taggedUsers {
            usernameToDisplayName[user.username.lowercased()] = user.displayName
        }
    }
    
    /// Get display name for a username, or return the original username if not found
    func displayName(for username: String) -> String {
        return usernameToDisplayName[username.lowercased()] ?? username
    }
    
    /// Add a user mapping
    mutating func addUser(_ user: User) {
        usernameToDisplayName[user.username.lowercased()] = user.displayName
    }
}

/// Parses and displays video titles with clickable @channel mentions and #hashtags
struct RichTextTitleView: View {
    let title: String
    let onChannelTap: ((String) -> Void)?
    let onHashtagTap: ((String) -> Void)?
    let channelMapper: ChannelMentionMapper?  // 🔥 YOUTUBE PARITY: For username → displayName mapping
    
    @State private var parsedSegments: [TextSegment] = []
    
    init(
        title: String,
        onChannelTap: ((String) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil,
        channelMapper: ChannelMentionMapper? = nil
    ) {
        self.title = title
        self.onChannelTap = onChannelTap
        self.onHashtagTap = onHashtagTap
        self.channelMapper = channelMapper
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
            switch segment.type {
            case .channel:
                // 🔥 YOUTUBE PARITY: Display channel name (displayName) instead of username
                let displayText: String
                if let username = segment.value, let mapper = channelMapper {
                    let channelName = mapper.displayName(for: username)
                    displayText = "@\(channelName)"
                } else {
                    displayText = segment.text
                }
                var attributedSegment = AttributedString(displayText)
                attributedSegment.foregroundColor = .red  // 🔥 YOUTUBE PARITY: Red color for @channel tags
                attributedSegment.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)
                result.append(attributedSegment)
                
            case .hashtag:
                var attributedSegment = AttributedString(segment.text)
                attributedSegment.foregroundColor = AppTheme.Colors.primary
                attributedSegment.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)
                result.append(attributedSegment)
                
            case .plain:
                var attributedSegment = AttributedString(segment.text)
                attributedSegment.foregroundColor = AppTheme.Colors.textPrimary
                result.append(attributedSegment)
            }
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
    let channelMapper: ChannelMentionMapper?  // 🔥 YOUTUBE PARITY: For username → displayName mapping
    
    init(
        title: String,
        onChannelTap: ((String) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil,
        textColor: Color? = nil,
        channelMapper: ChannelMentionMapper? = nil
    ) {
        self.title = title
        self.onChannelTap = onChannelTap
        self.onHashtagTap = onHashtagTap
        self.textColor = textColor
        self.channelMapper = channelMapper
    }
    
    var body: some View {
        parseAndDisplayTitle()
    }
    
    @ViewBuilder
    private func parseAndDisplayTitle() -> some View {
        let segments = parseTitle(title)
        
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                segmentView(for: segment)
            }
        }
    }
    
    @ViewBuilder
    private func segmentView(for segment: TextSegment) -> some View {
        switch segment.type {
        case .channel:
            if let username = segment.value {
                // 🔥 YOUTUBE PARITY: Display channel name instead of username
                let displayName = channelMapper?.displayName(for: username) ?? username
                Button(action: {
                    onChannelTap?(username)  // Pass username for lookup, not display name
                }) {
                    Text("@\(displayName)")
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
        Text("🔥 YOUTUBE PARITY: @username → @ChannelName")
            .font(.headline)
            .foregroundColor(.secondary)
        
        // Example: Creator's username is "sbkeonta_" but displayName is "ShotByKeonta"
        let testMapper = ChannelMentionMapper(
            creator: User(
                username: "sbkeonta_",
                displayName: "ShotByKeonta",
                email: "test@test.com",
                isCreator: true
            )
        )
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Before (without mapper):")
                .font(.caption)
                .foregroundColor(.secondary)
            InteractiveRichTextTitleView(
                title: "WayP - Leave (Remix) @sbkeonta_ #MusicVideo",
                onChannelTap: { channel in
                    print("Tapped channel: \(channel)")
                },
                onHashtagTap: { hashtag in
                    print("Tapped hashtag: \(hashtag)")
                }
            )
        }
        .padding()
        .background(AppTheme.Colors.surface.opacity(0.5))
        .cornerRadius(12)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("After (with mapper) - YouTube style:")
                .font(.caption)
                .foregroundColor(.secondary)
            InteractiveRichTextTitleView(
                title: "WayP - Leave (Remix) @sbkeonta_ #MusicVideo",
                onChannelTap: { channel in
                    print("Tapped channel: \(channel)")
                },
                onHashtagTap: { hashtag in
                    print("Tapped hashtag: \(hashtag)")
                },
                channelMapper: testMapper
            )
        }
        .padding()
        .background(AppTheme.Colors.surface.opacity(0.5))
        .cornerRadius(12)
        
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
    .padding()
    .background(AppTheme.Colors.background)
}

