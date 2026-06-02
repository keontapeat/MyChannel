//
//  PlayerSettingsSheet.swift
//  MyChannel
//
//  🔥 YOUTUBE PARITY: A real settings panel (like YouTube's gear sheet) instead of a
//  bare context menu. Rows for navigable options (Quality, Speed, Captions, Chapters,
//  Audio) show the current value and a chevron; on/off features (Loop, Ambient, Theater,
//  Stats) use inline toggles. Matches the app's dark-on-light sheet styling.
//

import SwiftUI

struct PlayerSettingsSheet: View {
    // Current values shown on the right of each navigable row
    let qualityLabel: String
    let speedLabel: String
    let audioLabel: String
    let captionsAvailable: Bool
    let chaptersAvailable: Bool

    // Toggles
    @Binding var isLooping: Bool
    @Binding var isAmbient: Bool
    @Binding var isTheater: Bool
    @Binding var showStats: Bool

    // Navigation actions (dismiss first, then open the corresponding selector)
    let onQuality: () -> Void
    let onSpeed: () -> Void
    let onCaptions: () -> Void
    let onChapters: () -> Void
    let onAudio: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Navigable rows
                    settingsRow(
                        icon: "aqi.medium",
                        title: "Quality",
                        value: qualityLabel
                    ) { dismissThen(onQuality) }

                    rowDivider

                    settingsRow(
                        icon: "speedometer",
                        title: "Playback speed",
                        value: speedLabel
                    ) { dismissThen(onSpeed) }

                    if captionsAvailable {
                        rowDivider
                        settingsRow(
                            icon: "captions.bubble",
                            title: "Captions",
                            value: "On / Off"
                        ) { dismissThen(onCaptions) }
                    }

                    if chaptersAvailable {
                        rowDivider
                        settingsRow(
                            icon: "list.bullet.rectangle",
                            title: "Chapters",
                            value: nil
                        ) { dismissThen(onChapters) }
                    }

                    rowDivider

                    settingsRow(
                        icon: "globe",
                        title: "Audio track",
                        value: audioLabel
                    ) { dismissThen(onAudio) }

                    sectionGap

                    // Toggle rows
                    toggleRow(icon: "repeat", title: "Loop video", isOn: $isLooping)
                    rowDivider
                    toggleRow(icon: "lightbulb", title: "Ambient mode", isOn: $isAmbient)
                    rowDivider
                    toggleRow(icon: "rectangle.expand.vertical", title: "Theater mode", isOn: $isTheater)
                    rowDivider
                    toggleRow(icon: "waveform.path.ecg", title: "Stats for nerds", isOn: $showStats)
                }
                .padding(.vertical, 8)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(
            UIKitSheetConfigurator(
                configuration: UIKitSheetConfiguration(
                    detents: [.medium(), .large()],
                    largestUndimmedDetentIdentifier: .large,
                    prefersGrabberVisible: true,
                    prefersScrollingExpandsWhenScrolledToEdge: true,
                    preferredCornerRadius: 28
                )
            )
        )
    }

    // MARK: - Rows

    private func settingsRow(icon: String, title: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 26)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(width: 26)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.Colors.primary)
                .onChange(of: isOn.wrappedValue) { _ in
                    HapticManager.shared.impact(style: .light)
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 60)
    }

    private var sectionGap: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface.opacity(0.35))
            .frame(height: 8)
            .padding(.vertical, 6)
    }

    private func dismissThen(_ action: @escaping () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            action()
        }
    }
}
