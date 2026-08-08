//
//  FlicksChromeViews.swift
//  MyChannel
//
//  Extracted top controls, loading, and creator videos sheet from FlicksView
//  for faster parallel compiles.
//

import SwiftUI

// MARK: - Top Controls

enum FlicksFeedMode: String, CaseIterable {
    case flicks = "Flicks"
    case following = "Following"
}

struct FlicksTopControls: View {
    @Binding var showSearchBar: Bool
    @Binding var searchText: String
    @Binding var flicksMuted: Bool
    @Binding var captionsEnabled: Bool
    @Binding var selectedFeed: FlicksFeedMode
    let creators: [FlickCreator]
    var showUI: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                HStack(spacing: 8) {
                    circularControl(icon: "magnifyingglass", label: "Search Flicks") {
                        showSearchBar.toggle()
                    }
                    Spacer()
                    circularControl(
                        icon: flicksMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        label: flicksMuted ? "Unmute" : "Mute"
                    ) {
                        flicksMuted.toggle()
                    }
                    circularControl(
                        icon: captionsEnabled ? "captions.bubble.fill" : "captions.bubble",
                        label: captionsEnabled ? "Turn off captions" : "Turn on captions"
                    ) {
                        captionsEnabled.toggle()
                    }
                }

                HStack(spacing: 18) {
                    ForEach(FlicksFeedMode.allCases, id: \.self) { mode in
                        Button {
                            selectedFeed = mode
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            VStack(spacing: 5) {
                                Text(mode.rawValue)
                                    .font(.system(size: 17, weight: selectedFeed == mode ? .bold : .semibold))
                                    .foregroundColor(selectedFeed == mode ? .white : .white.opacity(0.62))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: selectedFeed == mode ? 22 : 0, height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedFeed == mode ? .isSelected : [])
                    }

                    HStack(spacing: -7) {
                        ForEach(Array(creators.prefix(3))) { creator in
                            AppAsyncImage(
                                url: URL(string: creator.profileImageURL),
                                content: { $0.resizable().aspectRatio(contentMode: .fill) },
                                placeholder: { Circle().fill(Color.white.opacity(0.25)) }
                            )
                            .frame(width: 25, height: 25)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                            .accessibilityLabel(creator.displayName)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)

            if showSearchBar {
                searchField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: selectedFeed)
        .animation(.easeOut(duration: 0.2), value: showSearchBar)
        .opacity(showUI ? 1 : 0)
        .allowsHitTesting(showUI)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.65))
            TextField("Search Flicks", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.65))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 15, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.ultraThinMaterial.opacity(0.72), in: Capsule())
        .padding(.horizontal, 20)
    }

    private func circularControl(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.32), in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
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
