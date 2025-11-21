//
//  InteractiveStoryStickerView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/21/25.
//  🔥 INTERACTIVE STORY STICKERS - POLLS, LINKS, MENTIONS
//

import SwiftUI

// MARK: - Interactive Story Sticker Container
struct InteractiveStoryStickerView: View {
    let sticker: StorySticker
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Sticker background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                
                // Sticker content
                stickerContent
                    .padding(12)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var stickerContent: some View {
        switch sticker.type {
        case .mention:
            mentionSticker
        case .hashtag:
            hashtagSticker
        case .location:
            locationSticker
        case .poll:
            pollSticker
        case .time:
            timeSticker
        case .weather:
            weatherSticker
        case .emoji:
            emojiSticker
        case .gif, .countdown:
            defaultSticker
        }
    }
    
    private var mentionSticker: some View {
        HStack(spacing: 8) {
            Image(systemName: "at")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(sticker.data.displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var hashtagSticker: some View {
        HStack(spacing: 8) {
            Image(systemName: "number")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text(sticker.data.displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var locationSticker: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text(sticker.data.displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var pollSticker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(sticker.data.displayText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            
            Text("Tap to vote")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    
    private var timeSticker: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(sticker.data.displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var weatherSticker: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(sticker.data.displayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var emojiSticker: some View {
        Text(sticker.data.displayText)
            .font(.system(size: 40))
    }
    
    private var defaultSticker: some View {
        Text(sticker.data.displayText)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
    }
}

// MARK: - Story Poll Interaction View
struct StoryPollInteractionView: View {
    let poll: StoryPoll
    let onVote: (String) -> Void
    
    @State private var selectedOption: String?
    @State private var hasVoted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            Text(poll.question)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            // Options
            VStack(spacing: 12) {
                ForEach(poll.options) { option in
                    pollOption(option)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
    
    private func pollOption(_ option: StoryPoll.PollOption) -> some View {
        Button(action: {
            guard !hasVoted else { return }
            selectedOption = option.id
            hasVoted = true
            onVote(option.id)
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }) {
            ZStack(alignment: .leading) {
                // Background bar (result)
                if hasVoted {
                    let percentage = poll.totalVotes > 0 ? Double(option.voteCount) / Double(poll.totalVotes) : 0
                    let barColor = (Color(hex: option.color) ?? AppTheme.Colors.primary).opacity(0.6)
                    
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(barColor)
                            .frame(width: geometry.size.width * percentage)
                    }
                }
                
                HStack {
                    Text(option.text)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if hasVoted {
                        Text("\(option.voteCount)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if selectedOption == option.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(hasVoted)
    }
}

// MARK: - Story Link Swipe Up View
struct StoryLinkSwipeUpView: View {
    let link: StoryLink
    let onOpen: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Swipe up indicator
            VStack(spacing: 8) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Swipe up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(.black.opacity(0.6))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    )
            )
            
            // Link preview card
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    // Link thumbnail
                    if let imageURL = link.imageURL {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.surface)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Link info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if let description = link.description {
                            Text(description)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    StoryViewerView(
        stories: Story.sampleStories,
        initialStory: Story.sampleStories[0],
        onDismiss: {}
    )
}
