//
//  InteractiveStickerBadge.swift
//  MyChannel
//
//  Visual representation of a placed interactive sticker. Used both in the
//  creator (as a draggable preview) and as the base look in the viewer.
//

import SwiftUI

struct InteractiveStickerBadge: View {
    let kind: PlacedInteractiveSticker.Kind

    var body: some View {
        switch kind {
        case .poll(let question, let options):
            pollBadge(question: question, options: options)
        case .quiz(let question, let options, _):
            quizBadge(question: question, options: options)
        case .question(let prompt):
            questionBadge(prompt: prompt)
        case .slider(let prompt, let emoji):
            sliderBadge(prompt: prompt, emoji: emoji)
        case .countdown(let title, let endTime):
            countdownBadge(title: title, endTime: endTime)
        case .link(_, let title):
            chipBadge(icon: "link", text: title, tint: .green)
        case .mention(let username):
            chipBadge(icon: "at", text: username, tint: .cyan)
        case .location(let name):
            chipBadge(icon: "mappin.circle.fill", text: name, tint: .mint)
        case .hashtag(let tag):
            chipBadge(icon: "number", text: tag, tint: .indigo)
        }
    }

    // MARK: - Badges

    private func pollBadge(question: String, options: [String]) -> some View {
        VStack(spacing: 0) {
            Text(question.isEmpty ? "Poll" : question)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                    Text(opt)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    if idx < options.count - 1 {
                        Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1)
                    }
                }
            }
            .background(Color.white.opacity(0.85))
        }
        .frame(width: 220)
        .background(stickerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func quizBadge(question: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                Text(opt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Capsule().stroke(.white.opacity(0.5), lineWidth: 1.5))
            }
        }
        .padding(14)
        .frame(width: 230)
        .background(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func questionBadge(prompt: String) -> some View {
        VStack(spacing: 6) {
            Text(prompt)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
            Text("Type something…")
                .font(.system(size: 13))
                .foregroundStyle(.gray)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Color.black.opacity(0.06)))
        }
        .padding(14)
        .frame(width: 220)
        .background(stickerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sliderBadge(prompt: String, emoji: String) -> some View {
        VStack(spacing: 12) {
            Text(prompt)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                Text(emoji).font(.system(size: 30)).offset(x: 70)
            }
            .frame(height: 34)
        }
        .padding(14)
        .frame(width: 220)
        .background(stickerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func countdownBadge(title: String, endTime: Date) -> some View {
        VStack(spacing: 4) {
            Text(countdownString(to: endTime))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 22)
        .background(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func chipBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(text)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .overlay(Capsule().stroke(tint.opacity(0.8), lineWidth: 1.5))
    }

    private var stickerSurface: some View {
        Color.white
    }

    private func countdownString(to date: Date) -> String {
        let remaining = max(0, date.timeIntervalSinceNow)
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if days > 0 { return "\(days)d \(hours)h" }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Draggable creator wrapper

struct PlacedInteractiveStickerView: View {
    let sticker: PlacedInteractiveSticker
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDrag: (CGSize) -> Void
    let onScale: (CGFloat) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var liveScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                InteractiveStickerBadge(kind: sticker.kind)
                    .overlay(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                    .foregroundStyle(.white)
                                    .padding(-6)
                            }
                        }
                    )

                if isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .offset(x: 10, y: -10)
                }
            }
            .scaleEffect(sticker.scale * liveScale)
            .rotationEffect(.degrees(sticker.rotation))
            .position(
                x: sticker.position.x * geo.size.width + dragOffset.width,
                y: sticker.position.y * geo.size.height + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onSelect()
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        onDrag(value.translation)
                        dragOffset = .zero
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { liveScale = $0 }
                    .onEnded { value in
                        onScale(sticker.scale * value)
                        liveScale = 1.0
                    }
            )
            .onTapGesture { onSelect() }
        }
    }
}
