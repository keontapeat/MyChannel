//
//  StoryTextComposer.swift
//  MyChannel
//
//  ✍️ Instagram-style full-screen text composer for stories.
//  Lets the user type, pick a font, color, and background style. Produces a
//  configured EditableElement that the creator drops onto the canvas.
//

import SwiftUI

struct StoryTextComposerResult {
    let text: String
    let color: Color
    let font: StoryFont
    let background: TextBackgroundStyle
}

struct StoryTextComposer: View {
    /// Pre-filled values when editing an existing element.
    var initialText: String = ""
    var initialColor: Color = .white
    var initialFont: StoryFont = .bold
    var initialBackground: TextBackgroundStyle = .none

    let onDone: (StoryTextComposerResult) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @State private var color: Color
    @State private var font: StoryFont
    @State private var background: TextBackgroundStyle
    @FocusState private var isFocused: Bool

    private let palette: [Color] = [
        .white, .black, .red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink
    ]

    init(
        initialText: String = "",
        initialColor: Color = .white,
        initialFont: StoryFont = .bold,
        initialBackground: TextBackgroundStyle = .none,
        onDone: @escaping (StoryTextComposerResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialText = initialText
        self.initialColor = initialColor
        self.initialFont = initialFont
        self.initialBackground = initialBackground
        self.onDone = onDone
        self.onCancel = onCancel
        _text = State(initialValue: initialText)
        _color = State(initialValue: initialColor)
        _font = State(initialValue: initialFont)
        _background = State(initialValue: initialBackground)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                textField
                Spacer()
                controls
            }
            .padding(.vertical, 16)
        }
        .onAppear { isFocused = true }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .foregroundStyle(.white)
                .font(.system(size: 16, weight: .medium))

            Spacer()

            // Background style cycle (none → solid → gradient → outline)
            Button {
                background = background.next
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "a.square.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button("Done") {
                onDone(StoryTextComposerResult(text: text, color: color, font: font, background: background))
            }
            .foregroundStyle(.white)
            .font(.system(size: 16, weight: .bold))
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 18)
    }

    private var textField: some View {
        ZStack {
            if text.isEmpty {
                Text("Type something…")
                    .font(font.systemFont)
                    .foregroundStyle(.white.opacity(0.4))
            }
            TextField("", text: $text, axis: .vertical)
                .focused($isFocused)
                .font(font.systemFont)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .padding(14)
                .background(composerBackground)
                .padding(.horizontal, 24)
                .tint(.white)
        }
    }

    @ViewBuilder
    private var composerBackground: some View {
        switch background {
        case .none:
            Color.clear
        case .solid:
            RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6))
        case .gradient:
            RoundedRectangle(cornerRadius: 12).fill(
                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .outline:
            RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2)
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            // Font picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(StoryFont.allCases, id: \.self) { f in
                        Button {
                            font = f
                            HapticManager.shared.selection()
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(font == f ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(font == f ? Color.white : Color.white.opacity(0.15))
                                )
                        }
                    }
                }
                .padding(.horizontal, 18)
            }

            // Color picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(palette.indices, id: \.self) { i in
                        let c = palette[i]
                        Button {
                            color = c
                            HapticManager.shared.selection()
                        } label: {
                            Circle()
                                .fill(c)
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 3)
                                        .opacity(color == c ? 1 : 0)
                                        .padding(-3)
                                )
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 8)
    }
}

private extension TextBackgroundStyle {
    var next: TextBackgroundStyle {
        switch self {
        case .none: return .solid
        case .solid: return .gradient
        case .gradient: return .outline
        case .outline: return .none
        }
    }
}
