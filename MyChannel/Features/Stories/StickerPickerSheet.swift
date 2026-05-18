//
//  StickerPickerSheet.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct StickerPickerSheet: View {
    let onStickerSelected: (CreateStoryViewModel.StickerItem) -> Void
    
    @State private var selectedTab: StickerTab = .emoji
    @Environment(\.dismiss) private var dismiss
    
    enum StickerTab: CaseIterable {
        case emoji
        case gif
        case location
        case mention
        case hashtag
        case poll
        case time
        
        var title: String {
            switch self {
            case .emoji: return "Emoji"
            case .gif: return "GIF"
            case .location: return "Location"
            case .mention: return "Mention"
            case .hashtag: return "Hashtag"
            case .poll: return "Poll"
            case .time: return "Time"
            }
        }
        
        var icon: String {
            switch self {
            case .emoji: return "face.smiling.fill"
            case .gif: return "sparkles.tv"
            case .location: return "location.fill"
            case .mention: return "at"
            case .hashtag: return "number"
            case .poll: return "chart.bar.fill"
            case .time: return "clock.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(StickerTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                VStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : .gray)
                                    
                                    Text(tab.title)
                                        .font(.caption)
                                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : .gray)
                                }
                                .frame(width: 60)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Divider()
                
                // Content area
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .emoji:
                            EmojiStickerGrid(onEmojiSelected: { emoji in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .emoji,
                                    data: emoji
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })

                        case .gif:
                            GIFStickerView(onGIFSelected: { gif in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .emoji,
                                    data: gif
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })
                            
                        case .location:
                            LocationStickerView(onLocationSelected: { location in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .location,
                                    data: location
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })
                            
                        case .mention:
                            MentionStickerView(onMentionSelected: { username in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .mention,
                                    data: username
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })
                            
                        case .hashtag:
                            HashtagStickerView(onHashtagSelected: { hashtag in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .hashtag,
                                    data: hashtag
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })
                            
                        case .poll:
                            PollStickerView(onPollCreated: { poll in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .poll,
                                    data: poll
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })
                            
                        case .time:
                            TimeStickerView(onTimeSelected: { time in
                                let sticker = CreateStoryViewModel.StickerItem(
                                    type: .time,
                                    data: time
                                )
                                onStickerSelected(sticker)
                                dismiss()
                            })
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Sticker")
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
}

// MARK: - GIF Sticker View
struct GIFStickerView: View {
    let onGIFSelected: (String) -> Void

    @State private var searchText = ""
    @State private var suggestions = ["🔥", "✨", "😂", "💯", "😍", "🎉", "❤️", "🚀"]

    var body: some View {
        VStack(spacing: 16) {
            TextField("Search GIFs...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: searchText) { value in
                    Task {
                        suggestions = await StoryCreatorAssistService.shared.gifSuggestions(query: value)
                    }
                }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(suggestions, id: \.self) { gif in
                    Button(action: { onGIFSelected(gif) }) {
                        Text(gif)
                            .font(.system(size: 34))
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Emoji Sticker Grid
struct EmojiStickerGrid: View {
    let onEmojiSelected: (String) -> Void
    
    private let emojis = [
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
        "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
        "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔",
        "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "🤥",
        "😔", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢",
        "🎉", "🎊", "🎈", "🎁", "🎀", "🌟", "⭐", "✨", "💫", "⚡",
        "🔥", "❤️", "🧡", "💛", "💚", "💙", "💜", "🤍", "🖤", "💖"
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: { onEmojiSelected(emoji) }) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Location Sticker View
struct LocationStickerView: View {
    let onLocationSelected: (String) -> Void
    
    private let sampleLocations = [
        "San Francisco, CA", "New York, NY", "Los Angeles, CA", "Chicago, IL",
        "Miami, FL", "Seattle, WA", "Austin, TX", "Denver, CO"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(sampleLocations, id: \.self) { location in
                Button(action: { onLocationSelected(location) }) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(location)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Mention Sticker View
struct MentionStickerView: View {
    let onMentionSelected: (String) -> Void
    
    @State private var searchText = ""
    @State private var suggestions = [
        "john_doe", "jane_smith", "alex_wilson", "sarah_johnson",
        "mike_brown", "emma_davis", "chris_taylor", "lisa_anderson"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Search users...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: searchText) { value in
                    Task {
                        let results = await StoryCreatorAssistService.shared.mentionSuggestions(query: value, userId: AppState.shared.currentUser?.id)
                        if !results.isEmpty {
                            suggestions = results
                        }
                    }
                }
            
            ForEach(suggestions.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { username in
                Button(action: { onMentionSelected(username) }) {
                    HStack {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(username.prefix(1).uppercased()))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        
                        Text("@\(username)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Hashtag Sticker View
struct HashtagStickerView: View {
    let onHashtagSelected: (String) -> Void
    @State private var searchText = ""
    
    private let trendingHashtags = [
        "trending", "viral", "fyp", "love", "instagood", "photooftheday",
        "fashion", "beautiful", "happy", "cute", "tbt", "like4like"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Search hashtags...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            ForEach(trendingHashtags.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { hashtag in
                Button(action: { onHashtagSelected(hashtag) }) {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("#\(hashtag)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int.random(in: 100...9999))K")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Poll Sticker View
struct PollStickerView: View {
    let onPollCreated: (String) -> Void // Simplified for this example
    
    @State private var question = ""
    @State private var option1 = ""
    @State private var option2 = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create a Poll")
                .font(.headline)
            
            TextField("Ask a question...", text: $question)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Option 1", text: $option1)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Option 2", text: $option2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Create Poll") {
                let pollData = "\(question)|\(option1)|\(option2)"
                onPollCreated(pollData)
            }
            .disabled(question.isEmpty || option1.isEmpty || option2.isEmpty)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
    }
}

// MARK: - Time Sticker View
struct TimeStickerView: View {
    let onTimeSelected: (Date) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: { onTimeSelected(Date()) }) {
                VStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Current Time")
                        .font(.headline)
                    
                    Text(Date().formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    StickerPickerSheet { sticker in
        print("Sticker selected: \(sticker.type)")
    }
}