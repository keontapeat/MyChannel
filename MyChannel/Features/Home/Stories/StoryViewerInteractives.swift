//
//  StoryViewerInteractives.swift
//  MyChannel
//
//  Live, tappable interactive sticker components rendered inside the story
//  viewer (AssetStoriesPagerView): poll, emoji slider, plus the question
//  response composer and the "Seen by" sheet.
//

import SwiftUI

// MARK: - Live Poll

struct StoryInteractivePollView: View {
    let poll: StoryPoll
    let myVote: String?          // optionId the user already chose (if any)
    let onVote: (String) -> Void

    @State private var localVote: String?
    @State private var liveCounts: [String: Int]

    init(poll: StoryPoll, myVote: String?, onVote: @escaping (String) -> Void) {
        self.poll = poll
        self.myVote = myVote
        self.onVote = onVote
        _localVote = State(initialValue: myVote)
        // Seed with stored counts from the model.
        var counts: [String: Int] = [:]
        for opt in poll.options { counts[opt.id] = opt.voteCount }
        _liveCounts = State(initialValue: counts)
    }

    private var hasVoted: Bool { localVote != nil }
    private var totalVotes: Int { max(1, liveCounts.values.reduce(0, +)) }
    private var displayQuestion: String {
        // Quizzes are encoded as "[QUIZ:n] question" — strip the marker for display.
        if poll.question.hasPrefix("[QUIZ:"),
           let range = poll.question.range(of: "] ") {
            return String(poll.question[range.upperBound...])
        }
        return poll.question
    }

    var body: some View {
        VStack(spacing: 0) {
            if !displayQuestion.isEmpty {
                Text(displayQuestion)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
            }
            HStack(spacing: 0) {
                ForEach(Array(poll.options.enumerated()), id: \.element.id) { idx, option in
                    Button {
                        guard !hasVoted else { return }
                        localVote = option.id
                        liveCounts[option.id, default: 0] += 1
                        onVote(option.id)
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.text)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(localVote == option.id ? .white : .black)
                            if hasVoted {
                                Text("\(percentage(option.id))%")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(localVote == option.id ? .white : .black.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(localVote == option.id ? AppTheme.Colors.primary : Color.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .disabled(hasVoted)

                    if idx < poll.options.count - 1 {
                        Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1)
                    }
                }
            }
        }
        .frame(width: 240)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private func percentage(_ optionId: String) -> Int {
        let count = liveCounts[optionId] ?? 0
        return Int((Double(count) / Double(totalVotes) * 100).rounded())
    }
}

// MARK: - Live Emoji Slider

struct StoryInteractiveSliderView: View {
    let prompt: String
    let emoji: String
    let onSubmit: (Double) -> Void

    @State private var value: Double = 0.5
    @State private var submitted = false
    @GestureState private var dragging = false

    var body: some View {
        VStack(spacing: 12) {
            if !prompt.isEmpty {
                Text(prompt)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 8)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Text(emoji)
                        .font(.system(size: 34))
                        .scaleEffect(dragging ? 1.3 : 1.0)
                        .offset(x: max(0, min(geo.size.width - 34, value * geo.size.width - 17)))
                        .gesture(
                            DragGesture()
                                .updating($dragging) { _, state, _ in state = true }
                                .onChanged { g in
                                    value = min(1, max(0, g.location.x / geo.size.width))
                                }
                                .onEnded { _ in
                                    submitted = true
                                    onSubmit(value)
                                }
                        )
                }
            }
            .frame(height: 44)
            .frame(width: 200)

            if submitted {
                Text("Thanks!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}

// MARK: - Question response composer

struct StoryQuestionComposer: View {
    let prompt: String
    @Binding var response: String
    let isSubmitting: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            Text(prompt)
                .font(.system(size: 17, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Type your answer…", text: $response, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .padding(.horizontal)

            Button(action: onSend) {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text("Send")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.35) : AppTheme.Colors.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            .padding(.horizontal)

            Spacer()
        }
        .presentationDetents([.height(260)])
    }
}

// MARK: - Seen By sheet

struct StorySeenBySheet: View {
    let viewers: [User]
    let likedUserIds: Set<String>
    let isLoading: Bool
    let onTapViewer: (User) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading viewers…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "eye")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No views yet")
                            .font(.headline)
                        Text("When people view your story, you'll see them here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewers) { viewer in
                        Button {
                            onTapViewer(viewer)
                        } label: {
                            HStack(spacing: 12) {
                                avatar(for: viewer)
                                    .frame(width: 42, height: 42)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewer.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("@\(viewer.username)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if likedUserIds.contains(viewer.id) {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(viewers.count) view\(viewers.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        if let urlString = user.profileImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default:
                    Circle().fill(Color.gray.opacity(0.3))
                        .overlay(Text(String(user.username.prefix(1)).uppercased()).foregroundStyle(.white))
                }
            }
        } else {
            Circle().fill(Color.gray.opacity(0.3))
                .overlay(Text(String(user.username.prefix(1)).uppercased()).foregroundStyle(.white))
        }
    }
}
