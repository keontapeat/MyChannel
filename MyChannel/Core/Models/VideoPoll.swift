//
//  VideoPoll.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Video Poll Model (Interactive polls during video playback)
struct VideoPoll: Identifiable, Codable, Equatable {
    let id: String
    let videoId: String
    let question: String
    var options: [VideoPollOption]
    let timestamp: TimeInterval // When to show during playback
    let displayDuration: TimeInterval // How long poll stays visible (0 = until dismissed)
    let allowMultipleVotes: Bool
    let showResultsBeforeVoting: Bool
    let endsAt: Date?
    let createdAt: Date
    var totalVotes: Int
    var userVotedOptionIds: [String] // Track which options current user voted for
    
    init(
        id: String = UUID().uuidString,
        videoId: String,
        question: String,
        options: [VideoPollOption],
        timestamp: TimeInterval,
        displayDuration: TimeInterval = 15.0,
        allowMultipleVotes: Bool = false,
        showResultsBeforeVoting: Bool = false,
        endsAt: Date? = nil,
        createdAt: Date = Date(),
        totalVotes: Int = 0,
        userVotedOptionIds: [String] = []
    ) {
        self.id = id
        self.videoId = videoId
        self.question = question
        self.options = options
        self.timestamp = timestamp
        self.displayDuration = displayDuration
        self.allowMultipleVotes = allowMultipleVotes
        self.showResultsBeforeVoting = showResultsBeforeVoting
        self.endsAt = endsAt
        self.createdAt = createdAt
        self.totalVotes = totalVotes
        self.userVotedOptionIds = userVotedOptionIds
    }
    
    // MARK: - Computed Properties
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isActive: Bool {
        if let endsAt = endsAt {
            return Date() < endsAt
        }
        return true
    }
    
    var hasUserVoted: Bool {
        !userVotedOptionIds.isEmpty
    }
    
    var winningOption: VideoPollOption? {
        options.max(by: { $0.voteCount < $1.voteCount })
    }
    
    // MARK: - Methods
    mutating func vote(for optionId: String) {
        guard isActive else { return }
        guard !userVotedOptionIds.contains(optionId) else { return }
        
        if !allowMultipleVotes && hasUserVoted {
            // Remove previous vote
            if let previousVoteId = userVotedOptionIds.first,
               let index = options.firstIndex(where: { $0.id == previousVoteId }) {
                options[index].voteCount -= 1
                totalVotes -= 1
            }
            userVotedOptionIds.removeAll()
        }
        
        if let index = options.firstIndex(where: { $0.id == optionId }) {
            options[index].voteCount += 1
            totalVotes += 1
            userVotedOptionIds.append(optionId)
        }
    }
}

// MARK: - Video Poll Option
struct VideoPollOption: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let text: String
    let imageURL: String?
    var voteCount: Int
    let order: Int
    
    init(
        id: String = UUID().uuidString,
        text: String,
        imageURL: String? = nil,
        voteCount: Int = 0,
        order: Int = 0
    ) {
        self.id = id
        self.text = text
        self.imageURL = imageURL
        self.voteCount = voteCount
        self.order = order
    }
    
    func percentage(of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(voteCount) / Double(total) * 100
    }
}

// MARK: - Poll Style
enum PollStyle: String, Codable, CaseIterable {
    case standard = "standard"
    case imageGrid = "image_grid"
    case slider = "slider"
    case emoji = "emoji"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .imageGrid: return "Image Grid"
        case .slider: return "Slider"
        case .emoji: return "Emoji Reaction"
        }
    }
}

// MARK: - Sample Data
extension VideoPoll {
    static let samplePolls: [VideoPoll] = [
        VideoPoll(
            videoId: "video-1",
            question: "What programming language should I cover next?",
            options: [
                VideoPollOption(text: "Python", voteCount: 1250, order: 0),
                VideoPollOption(text: "Rust", voteCount: 890, order: 1),
                VideoPollOption(text: "Go", voteCount: 720, order: 2),
                VideoPollOption(text: "TypeScript", voteCount: 650, order: 3)
            ],
            timestamp: 120,
            displayDuration: 20,
            totalVotes: 3510
        ),
        VideoPoll(
            videoId: "video-1",
            question: "Did you find this tutorial helpful?",
            options: [
                VideoPollOption(text: "🔥 Very helpful!", voteCount: 2340, order: 0),
                VideoPollOption(text: "👍 Somewhat helpful", voteCount: 560, order: 1),
                VideoPollOption(text: "😕 Could be better", voteCount: 120, order: 2),
                VideoPollOption(text: "👎 Not helpful", voteCount: 45, order: 3)
            ],
            timestamp: 300,
            displayDuration: 15,
            totalVotes: 3065
        ),
        VideoPoll(
            videoId: "video-2",
            question: "Which feature do you want me to build?",
            options: [
                VideoPollOption(text: "Dark Mode Toggle", voteCount: 890, order: 0),
                VideoPollOption(text: "Push Notifications", voteCount: 1200, order: 1),
                VideoPollOption(text: "Offline Support", voteCount: 750, order: 2),
                VideoPollOption(text: "Multi-language", voteCount: 420, order: 3)
            ],
            timestamp: 180,
            displayDuration: 0, // Stays until dismissed
            allowMultipleVotes: false,
            totalVotes: 3260
        )
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            Text("Video Polls")
                .font(AppTheme.Typography.largeTitle)
                .padding(.top)
            
            ForEach(VideoPoll.samplePolls) { poll in
                VStack(alignment: .leading, spacing: 16) {
                    // Question
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(poll.question)
                            .font(AppTheme.Typography.headline)
                        
                        Spacer()
                        
                        Text("@ \(poll.formattedTimestamp)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    // Options with progress bars
                    ForEach(poll.options) { option in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(option.text)
                                    .font(AppTheme.Typography.subheadline)
                                
                                Spacer()
                                
                                Text("\(Int(option.percentage(of: poll.totalVotes)))%")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.Colors.surface)
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            option == poll.winningOption
                                            ? AppTheme.Colors.primary
                                            : AppTheme.Colors.secondary.opacity(0.6)
                                        )
                                        .frame(
                                            width: geometry.size.width * option.percentage(of: poll.totalVotes) / 100,
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    
                    // Total votes
                    HStack {
                        Text("\(poll.totalVotes.formatted()) votes")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        if poll.isActive {
                            Text("Active")
                                .font(AppTheme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.success)
                        } else {
                            Text("Ended")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                }
                .padding()
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.CornerRadius.lg)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.background)
}



