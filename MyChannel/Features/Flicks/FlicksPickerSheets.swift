//
//  FlicksPickerSheets.swift
//  MyChannel
//
//  Extracted quality / speed pickers from FlicksView for faster parallel compiles.
//

import SwiftUI

struct FlicksQualityPickerSheet: View {
    @Binding var preferredQuality: String
    @Binding var isPresented: Bool
    var onSelect: (() -> Void)? = nil

    private let qualities = ["auto", "360p", "480p", "720p", "1080p"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Video Quality")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 12) {
                    ForEach(qualities, id: \.self) { quality in
                        Button {
                            preferredQuality = quality
                            isPresented = false
                            onSelect?()
                            HapticManager.shared.impact(style: .medium)
                        } label: {
                            HStack {
                                Text(quality.uppercased())
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if preferredQuality == quality {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(preferredQuality == quality ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            )
                        }
                        .accessibilityLabel("Quality \(quality)")
                        .accessibilityAddTraits(preferredQuality == quality ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct FlicksSpeedPickerSheet: View {
    @Binding var playbackSpeed: Double
    @Binding var isPresented: Bool
    var onSelect: (() -> Void)? = nil

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Playback Speed")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 12) {
                    ForEach(speeds, id: \.self) { speed in
                        Button {
                            playbackSpeed = speed
                            isPresented = false
                            onSelect?()
                            HapticManager.shared.impact(style: .medium)
                        } label: {
                            HStack {
                                Text("\(speed)x")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if playbackSpeed == speed {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(playbackSpeed == speed ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            )
                        }
                        .accessibilityLabel("Speed \(speed)x")
                        .accessibilityAddTraits(playbackSpeed == speed ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// More-options sheet extracted from FlicksView (report / not interested / playlist).
struct FlicksMoreOptionsSheet: View {
    let onReport: () -> Void
    let onNotInterested: () -> Void
    let onAddToPlaylist: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("More Options")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .background(Color.gray.opacity(0.3))

                VStack(spacing: 0) {
                    moreOptionRow(icon: "exclamationmark.triangle", title: "Report", color: .red, action: {
                        onReport()
                        onDismiss()
                    })
                    Divider().background(Color.gray.opacity(0.3))
                    moreOptionRow(icon: "hand.thumbsdown", title: "Not Interested", color: .orange, action: {
                        onNotInterested()
                        onDismiss()
                    })
                    Divider().background(Color.gray.opacity(0.3))
                    moreOptionRow(icon: "plus.rectangle.on.rectangle", title: "Add to Playlist", color: .blue, action: {
                        onDismiss()
                        onAddToPlaylist()
                    })
                }

                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private func moreOptionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .accessibilityLabel(title)
    }
}

#Preview("Quality") {
    FlicksQualityPickerSheet(preferredQuality: .constant("auto"), isPresented: .constant(true))
}

#Preview("Speed") {
    FlicksSpeedPickerSheet(playbackSpeed: .constant(1.0), isPresented: .constant(true))
}

#Preview("More Options") {
    FlicksMoreOptionsSheet(
        onReport: {},
        onNotInterested: {},
        onAddToPlaylist: {},
        onDismiss: {}
    )
}
