//
//  HomeFilterChipsBar.swift
//  MyChannel
//
//  YouTube-parity horizontal filter chips for the Home feed.
//  Chips: All · Music · Live · Gaming · News · Recently uploaded · Watched
//

import SwiftUI

// MARK: - Chip Model
enum HomeFilterChip: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case music = "Music"
    case live = "Live"
    case gaming = "Gaming"
    case news = "News"
    case mixes = "Mixes"
    case podcasts = "Podcasts"
    case recentlyUploaded = "Recently uploaded"
    case watched = "Watched"
    case newToYou = "New to you"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

// MARK: - Chips Bar
struct HomeFilterChipsBar: View {
    @Binding var selected: HomeFilterChip
    let onChipTap: (HomeFilterChip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeFilterChip.allCases) { chip in
                    chipButton(chip)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func chipButton(_ chip: HomeFilterChip) -> some View {
        let isSelected = selected == chip
        Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                selected = chip
            }
            onChipTap(chip)
        } label: {
            Text(chip.displayName)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.primary : Color(.systemGray6))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(chip.displayName) filter")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    StatefulPreviewWrapper(HomeFilterChip.all) { binding in
        HomeFilterChipsBar(selected: binding, onChipTap: { _ in })
    }
    .padding(.vertical)
}

// MARK: - Preview Helper
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(wrappedValue: initial)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
