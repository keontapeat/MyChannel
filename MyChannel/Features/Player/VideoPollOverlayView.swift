//
//  VideoPollOverlayView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Video Poll Overlay View (Shows during video playback)
struct VideoPollOverlayView: View {
    @Binding var poll: VideoPoll
    let onVote: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedOptionId: String?
    @State private var showResults = false
    @State private var isVisible = false
    @State private var isMinimized = false
    
    var body: some View {
        VStack {
            if isMinimized {
                minimizedView
            } else {
                Spacer()
                
                HStack {
                    Spacer()
                    expandedPollView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Above player controls
            }
        }
        .onAppear {
            showResults = poll.hasUserVoted || poll.showResultsBeforeVoting
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - Minimized View
    private var minimizedView: some View {
        VStack {
            HStack {
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isMinimized = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.white)
                        
                        Text("Poll")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if poll.hasUserVoted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.Colors.success)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Expanded Poll View
    private var expandedPollView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Poll")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Minimize button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isMinimized = true
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                
                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Question
            Text(poll.question)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            // Options
            VStack(spacing: 8) {
                ForEach(poll.options) { option in
                    if showResults || poll.hasUserVoted {
                        pollResultRow(option: option)
                    } else {
                        pollOptionButton(option: option)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Footer
            HStack {
                Text("\(poll.totalVotes.formatted()) votes")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if poll.hasUserVoted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Voted")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.success)
                } else if poll.isActive {
                    Text("Tap to vote")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
    }
    
    // MARK: - Poll Option Button
    private func pollOptionButton(option: VideoPollOption) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedOptionId = option.id
                onVote(option.id)
                showResults = true
            }
        } label: {
            HStack {
                Text(option.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PollOptionButtonStyle())
    }
    
    // MARK: - Poll Result Row
    private func pollResultRow(option: VideoPollOption) -> some View {
        let percentage = option.percentage(of: poll.totalVotes)
        let isWinning = option == poll.winningOption
        let isUserVote = poll.userVotedOptionIds.contains(option.id)
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.text)
                    .font(.system(size: 14, weight: isUserVote ? .semibold : .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    if isUserVote {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.success)
                    }
                    
                    Text("\(Int(percentage))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isWinning ? AppTheme.Colors.primary : .white.opacity(0.8))
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            isWinning
                            ? AppTheme.Colors.primary
                            : (isUserVote ? AppTheme.Colors.secondary : .white.opacity(0.4))
                        )
                        .frame(width: geometry.size.width * percentage / 100, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: percentage)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isUserVote ? .white.opacity(0.15) : .white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isUserVote ? AppTheme.Colors.primary.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: isUserVote ? 2 : 1
                        )
                )
        )
    }
}

// MARK: - Poll Option Button Style
struct PollOptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Poll Container View (Manages poll during playback)
struct PollContainerView: View {
    @ObservedObject var manager: PollPlaybackManager
    
    var body: some View {
        if manager.showPoll, var poll = manager.currentPoll {
            VideoPollOverlayView(
                poll: Binding(
                    get: { poll },
                    set: { poll = $0 }
                ),
                onVote: { optionId in
                    Task {
                        await manager.vote(for: optionId)
                    }
                },
                onDismiss: {
                    manager.dismissPoll()
                }
            )
        }
    }
}

// MARK: - Poll Creator View (For Studio)
struct PollCreatorView: View {
    let videoId: String
    let videoDuration: TimeInterval
    let onSave: (VideoPoll) -> Void
    
    @State private var question = ""
    @State private var options: [String] = ["", ""]
    @State private var timestamp: TimeInterval = 0
    @State private var displayDuration: TimeInterval = 15
    @State private var allowMultipleVotes = false
    @State private var showResultsBeforeVoting = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Question
                Section("Question") {
                    TextField("Ask a question...", text: $question, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                // Options
                Section {
                    ForEach(options.indices, id: \.self) { index in
                        HStack {
                            TextField("Option \(index + 1)", text: $options[index])
                            
                            if options.count > 2 {
                                Button {
                                    options.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(AppTheme.Colors.error)
                                }
                            }
                        }
                    }
                    
                    if options.count < 4 {
                        Button {
                            options.append("")
                        } label: {
                            Label("Add Option", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("Options (2-4)")
                }
                
                // Timing
                Section("Timing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Show at:")
                            Spacer()
                            Text(formatDuration(timestamp))
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Slider(value: $timestamp, in: 0...videoDuration, step: 1)
                            .tint(AppTheme.Colors.primary)
                    }
                    
                    Picker("Display Duration", selection: $displayDuration) {
                        Text("10 seconds").tag(TimeInterval(10))
                        Text("15 seconds").tag(TimeInterval(15))
                        Text("20 seconds").tag(TimeInterval(20))
                        Text("30 seconds").tag(TimeInterval(30))
                        Text("Until dismissed").tag(TimeInterval(0))
                    }
                }
                
                // Settings
                Section("Settings") {
                    Toggle("Allow Multiple Votes", isOn: $allowMultipleVotes)
                    Toggle("Show Results Before Voting", isOn: $showResultsBeforeVoting)
                }
                
                // Preview
                Section("Preview") {
                    previewView
                }
            }
            .navigationTitle("Create Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        savePoll()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    // MARK: - Preview
    private var previewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.isEmpty ? "Your question here" : question)
                .font(AppTheme.Typography.headline)
                .foregroundColor(question.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
            
            ForEach(options.indices, id: \.self) { index in
                HStack {
                    Text(options[index].isEmpty ? "Option \(index + 1)" : options[index])
                        .font(AppTheme.Typography.body)
                        .foregroundColor(options[index].isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Circle()
                        .stroke(AppTheme.Colors.textTertiary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Helper Methods
    private var isValid: Bool {
        !question.isEmpty && options.filter { !$0.isEmpty }.count >= 2
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func savePoll() {
        let pollOptions = options.enumerated().compactMap { index, text -> VideoPollOption? in
            guard !text.isEmpty else { return nil }
            return VideoPollOption(text: text, order: index)
        }
        
        let poll = VideoPoll(
            videoId: videoId,
            question: question,
            options: pollOptions,
            timestamp: timestamp,
            displayDuration: displayDuration,
            allowMultipleVotes: allowMultipleVotes,
            showResultsBeforeVoting: showResultsBeforeVoting
        )
        
        onSave(poll)
        dismiss()
    }
}

// MARK: - Polls Manager View (For Studio)
struct PollsManagerView: View {
    let videoId: String
    let videoDuration: TimeInterval
    
    @StateObject private var service = VideoPollService.shared
    @State private var polls: [VideoPoll] = []
    @State private var showCreatePoll = false
    @State private var isLoading = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading polls...")
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.lg) {
                            // Info
                            infoSection
                            
                            // Timeline
                            timelineView
                            
                            // Polls List
                            pollsListView
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Video Polls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreatePoll = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showCreatePoll) {
                PollCreatorView(
                    videoId: videoId,
                    videoDuration: videoDuration
                ) { newPoll in
                    Task {
                        try? await service.createPoll(newPoll)
                        await loadPolls()
                    }
                }
            }
            .task {
                await loadPolls()
            }
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("About Video Polls")
                    .font(AppTheme.Typography.headline)
            }
            
            Text("Polls appear during video playback to engage viewers. They can vote in real-time and see results instantly.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Timeline View
    private var timelineView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Timeline")
                .font(AppTheme.Typography.headline)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.surface)
                        .frame(height: 40)
                    
                    ForEach(polls) { poll in
                        let position = CGFloat(poll.timestamp / videoDuration) * geometry.size.width
                        
                        VStack(spacing: 2) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(AppTheme.Colors.primary)
                                .clipShape(Circle())
                            
                            Rectangle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 2, height: 12)
                        }
                        .position(x: position, y: 20)
                    }
                }
            }
            .frame(height: 50)
            
            HStack {
                Text("0:00")
                Spacer()
                Text(formatDuration(videoDuration / 2))
                Spacer()
                Text(formatDuration(videoDuration))
            }
            .font(AppTheme.Typography.caption2)
            .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Polls List View
    private var pollsListView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Polls (\(polls.count))")
                .font(AppTheme.Typography.headline)
            
            if polls.isEmpty {
                emptyStateView
            } else {
                ForEach(polls) { poll in
                    PollRowView(poll: poll) {
                        Task {
                            try? await service.deletePoll(id: poll.id)
                            await loadPolls()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No polls yet")
                .font(AppTheme.Typography.headline)
            
            Text("Create a poll to engage your viewers during the video.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                showCreatePoll = true
            } label: {
                Label("Create Poll", systemImage: "plus")
                    .font(AppTheme.Typography.bodyMedium)
            }
            .modernButtonStyle()
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
    
    // MARK: - Helper Methods
    private func loadPolls() async {
        isLoading = true
        do {
            polls = try await service.getPolls(for: videoId)
        } catch {
            print("Failed to load polls: \(error)")
        }
        isLoading = false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Poll Row View
struct PollRowView: View {
    let poll: VideoPoll
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text(poll.question)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                
                Spacer()
                
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            // Options preview
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(poll.options.prefix(3)) { option in
                    Text(option.text)
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(4)
                }
                
                if poll.options.count > 3 {
                    Text("+\(poll.options.count - 3)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            HStack {
                Label("@ \(poll.formattedTimestamp)", systemImage: "clock")
                
                Text("•")
                
                Text("\(poll.totalVotes) votes")
                
                Spacer()
                
                Text(poll.isActive ? "Active" : "Ended")
                    .foregroundColor(poll.isActive ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)
            }
            .font(AppTheme.Typography.caption)
            .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .confirmationDialog("Delete Poll?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This poll will be permanently removed.")
        }
    }
}

#Preview("Poll Overlay") {
    ZStack {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.black, .gray.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        
        VideoPollOverlayView(
            poll: .constant(VideoPoll.samplePolls[0]),
            onVote: { _ in },
            onDismiss: { }
        )
    }
    .ignoresSafeArea()
}

#Preview("Poll Creator") {
    PollCreatorView(
        videoId: "video-1",
        videoDuration: 600
    ) { _ in }
}

#Preview("Polls Manager") {
    PollsManagerView(videoId: "video-1", videoDuration: 600)
}
