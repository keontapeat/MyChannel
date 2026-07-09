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

#Preview("Quality") {
    FlicksQualityPickerSheet(preferredQuality: .constant("auto"), isPresented: .constant(true))
}

#Preview("Speed") {
    FlicksSpeedPickerSheet(playbackSpeed: .constant(1.0), isPresented: .constant(true))
}
