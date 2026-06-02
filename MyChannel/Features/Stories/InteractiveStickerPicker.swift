//
//  InteractiveStickerPicker.swift
//  MyChannel
//
//  📊 Instagram-style interactive sticker picker + configuration sheets.
//  Lets creators add Poll, Quiz, Question, Emoji Slider, Countdown, Link,
//  Mention, Location, and Hashtag stickers to a story.
//

import SwiftUI

// MARK: - Picker grid

struct InteractiveStickerPicker: View {
    let onPick: (InteractiveStickerType) -> Void
    let onDismiss: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(InteractiveStickerType.allCases) { type in
                        Button {
                            HapticManager.shared.impact(style: .light)
                            onPick(type)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(type.tint.opacity(0.18))
                                        .frame(height: 72)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(type.tint)
                                }
                                Text(type.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { onDismiss() }
                }
            }
        }
    }
}

enum InteractiveStickerType: String, CaseIterable, Identifiable {
    case poll, quiz, question, slider, countdown, link, mention, location, hashtag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .poll: return "Poll"
        case .quiz: return "Quiz"
        case .question: return "Questions"
        case .slider: return "Emoji Slider"
        case .countdown: return "Countdown"
        case .link: return "Link"
        case .mention: return "Mention"
        case .location: return "Location"
        case .hashtag: return "Hashtag"
        }
    }

    var icon: String {
        switch self {
        case .poll: return "chart.bar.fill"
        case .quiz: return "questionmark.app.fill"
        case .question: return "bubble.left.and.bubble.right.fill"
        case .slider: return "slider.horizontal.below.square.filled.and.square"
        case .countdown: return "timer"
        case .link: return "link"
        case .mention: return "at"
        case .location: return "mappin.circle.fill"
        case .hashtag: return "number"
        }
    }

    var tint: Color {
        switch self {
        case .poll: return .blue
        case .quiz: return .purple
        case .question: return .pink
        case .slider: return .orange
        case .countdown: return .red
        case .link: return .green
        case .mention: return .cyan
        case .location: return .mint
        case .hashtag: return .indigo
        }
    }
}

// MARK: - Configuration sheet

struct InteractiveStickerConfigSheet: View {
    let type: InteractiveStickerType
    let onComplete: (PlacedInteractiveSticker.Kind) -> Void
    let onCancel: () -> Void

    // Shared fields
    @State private var prompt: String = ""
    @State private var optionA: String = "Yes"
    @State private var optionB: String = "No"
    @State private var optionC: String = ""
    @State private var optionD: String = ""
    @State private var correctIndex: Int = 0
    @State private var sliderEmoji: String = "😍"
    @State private var linkURL: String = ""
    @State private var linkTitle: String = ""
    @State private var countdownTitle: String = ""
    @State private var countdownDate: Date = Date().addingTimeInterval(3600)
    @State private var freeText: String = ""

    private let sliderEmojiChoices = ["😍", "🔥", "😂", "😮", "👏", "❤️", "💯", "🎉"]

    var body: some View {
        NavigationStack {
            Form {
                switch type {
                case .poll:
                    pollSection(title: "Ask a question")
                case .quiz:
                    quizSection
                case .question:
                    Section("Ask me anything") {
                        TextField("Ask a question…", text: $prompt)
                    }
                case .slider:
                    Section("Slider prompt") {
                        TextField("Ask something…", text: $prompt)
                    }
                    Section("Emoji") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(sliderEmojiChoices, id: \.self) { e in
                                    Text(e)
                                        .font(.system(size: 30))
                                        .padding(6)
                                        .background(Circle().fill(sliderEmoji == e ? Color.accentColor.opacity(0.25) : .clear))
                                        .onTapGesture { sliderEmoji = e }
                                }
                            }
                        }
                    }
                case .countdown:
                    Section("Countdown") {
                        TextField("Title (e.g. Drop day)", text: $countdownTitle)
                        DatePicker("Ends", selection: $countdownDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    }
                case .link:
                    Section("Link") {
                        TextField("https://…", text: $linkURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        TextField("Label (optional)", text: $linkTitle)
                    }
                case .mention:
                    Section("Mention") {
                        HStack {
                            Text("@").foregroundStyle(.secondary)
                            TextField("username", text: $freeText)
                                .textInputAutocapitalization(.never)
                        }
                    }
                case .location:
                    Section("Location") {
                        TextField("Place name", text: $freeText)
                    }
                case .hashtag:
                    Section("Hashtag") {
                        HStack {
                            Text("#").foregroundStyle(.secondary)
                            TextField("topic", text: $freeText)
                                .textInputAutocapitalization(.never)
                        }
                    }
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { complete() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    @ViewBuilder
    private func pollSection(title: String) -> some View {
        Section(title) {
            TextField("Question (optional)", text: $prompt)
        }
        Section("Options") {
            TextField("Option 1", text: $optionA)
            TextField("Option 2", text: $optionB)
        }
    }

    @ViewBuilder
    private var quizSection: some View {
        Section("Question") {
            TextField("Ask a question…", text: $prompt)
        }
        Section("Options (tap the correct one)") {
            quizOption(0, $optionA, placeholder: "Option 1")
            quizOption(1, $optionB, placeholder: "Option 2")
            quizOption(2, $optionC, placeholder: "Option 3 (optional)")
            quizOption(3, $optionD, placeholder: "Option 4 (optional)")
        }
    }

    private func quizOption(_ index: Int, _ binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            Button {
                correctIndex = index
            } label: {
                Image(systemName: correctIndex == index ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(correctIndex == index ? .green : .secondary)
            }
            .buttonStyle(.plain)
            TextField(placeholder, text: binding)
        }
    }

    private var isValid: Bool {
        switch type {
        case .poll:
            return !optionA.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !optionB.trimmingCharacters(in: .whitespaces).isEmpty
        case .quiz:
            return !prompt.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !optionA.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !optionB.trimmingCharacters(in: .whitespaces).isEmpty
        case .question, .slider:
            return !prompt.trimmingCharacters(in: .whitespaces).isEmpty
        case .countdown:
            return !countdownTitle.trimmingCharacters(in: .whitespaces).isEmpty
        case .link:
            return URL(string: linkURL.trimmingCharacters(in: .whitespaces)) != nil && linkURL.contains(".")
        case .mention, .location, .hashtag:
            return !freeText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func complete() {
        let kind: PlacedInteractiveSticker.Kind
        switch type {
        case .poll:
            kind = .poll(
                question: prompt.isEmpty ? "Poll" : prompt,
                options: [optionA, optionB].map { $0.trimmingCharacters(in: .whitespaces) }
            )
        case .quiz:
            let opts = [optionA, optionB, optionC, optionD]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            kind = .quiz(question: prompt, options: opts, correctIndex: min(correctIndex, opts.count - 1))
        case .question:
            kind = .question(prompt: prompt)
        case .slider:
            kind = .slider(prompt: prompt, emoji: sliderEmoji)
        case .countdown:
            kind = .countdown(title: countdownTitle, endTime: countdownDate)
        case .link:
            let title = linkTitle.isEmpty ? (URL(string: linkURL)?.host ?? "Link") : linkTitle
            kind = .link(url: linkURL.trimmingCharacters(in: .whitespaces), title: title)
        case .mention:
            kind = .mention(username: freeText.trimmingCharacters(in: .whitespaces))
        case .location:
            kind = .location(name: freeText.trimmingCharacters(in: .whitespaces))
        case .hashtag:
            kind = .hashtag(tag: freeText.trimmingCharacters(in: .whitespaces))
        }
        HapticManager.shared.notification(type: .success)
        onComplete(kind)
    }
}
