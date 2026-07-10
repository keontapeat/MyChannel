//
//  FlicksChromeViews.swift
//  MyChannel
//
//  Extracted top controls, loading, and creator videos sheet from FlicksView
//  for faster parallel compiles.
//

import SwiftUI

// MARK: - Top Controls

struct FlicksTopControls: View {
    @Binding var showSearchBar: Bool
    @Binding var searchText: String
    @Binding var flicksMuted: Bool
    @Binding var captionsEnabled: Bool
    var showUI: Bool

    var body: some View {
        VStack {
            HStack {
                Button {
                    showSearchBar.toggle()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)

                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Search Flicks")

                Button {
                    flicksMuted.toggle()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)

                        Image(systemName: flicksMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(flicksMuted ? "Unmute" : "Mute")

                Button {
                    captionsEnabled.toggle()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    ZStack {
                        Circle()
                            .fill(captionsEnabled ? Color.white.opacity(0.9) : Color.black.opacity(0.55))
                            .frame(width: 44, height: 44)

                        Image(systemName: "captions.bubble.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(captionsEnabled ? .black : .white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(captionsEnabled ? "Turn off captions" : "Turn on captions")

                Spacer()
            }
            .padding(.top, 56)
            .padding(.trailing, 24)
            .padding(.leading, 20)

            if showSearchBar {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))

                    TextField("Search Flicks...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .accessibilityLabel("Search Flicks")

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.55))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .opacity(showUI ? 1 : 0)
        .allowsHitTesting(showUI)
    }
}

// MARK: - Loading View

struct FlicksLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)

            Text("Loading Flicks...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading Flicks")
    }
}

// MARK: - Creator Videos Sheet

struct FlicksCreatorVideosSheet: View {
    let creatorVideos: [NuclearFlick]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Close")

                    Spacer()

                    Text("Creator's Videos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Color.clear.frame(width: 36)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .background(Color.gray.opacity(0.3))

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(creatorVideos) { flick in
                            VStack(spacing: 8) {
                                AppAsyncImage(
                                    url: URL(string: flick.thumbnailURL),
                                    content: { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    },
                                    placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
                                )
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(flick.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)

                                    Text("\(Self.formatCount(flick.viewCount)) views")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(flick.title), \(Self.formatCount(flick.viewCount)) views")
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}
