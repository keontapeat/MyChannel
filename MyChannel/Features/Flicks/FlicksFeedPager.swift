//
//  FlicksFeedPager.swift
//  MyChannel
//
//  Vertical TabView feed pager extracted from FlicksView.
//
//  Prefetch policy: parent calls preloadVideos with visible+1 (current + next) on index
//  change — this pager does not widen the window. See docs/launch-perf-flicks.md.
//

import SwiftUI

struct FlicksFeedPager<FlickCard: View>: View {
    let filteredFlicks: [NuclearFlick]
    @Binding var currentIndex: Int
    @Binding var showSearchBar: Bool
    @Binding var searchText: String
    @Binding var flicksMuted: Bool
    @Binding var captionsEnabled: Bool
    let showUI: Bool
    let reduceMotion: Bool
    let flicksCount: Int
    let commentsFlick: NuclearFlick?
    let isLoadingMore: Bool
    let doubleTapHeartVisible: Bool
    let doubleTapHeartID: UUID
    let onIndexChange: (Int) -> Void
    let onFlickAppear: (Int) -> Void
    let onFlickDisappear: (Int) -> Void
    let onProgressRailSelect: (Int) -> Void
    @ViewBuilder let flickCard: (NuclearFlick, Int, GeometryProxy) -> FlickCard

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(filteredFlicks.enumerated()), id: \.element.id) { index, flick in
                        flickCard(flick, index, geometry)
                            .frame(width: screenWidth, height: screenHeight)
                            .ignoresSafeArea()
                            .tag(index)
                            .onAppear { onFlickAppear(index) }
                            .onDisappear { onFlickDisappear(index) }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: screenWidth, height: screenHeight)
                .ignoresSafeArea()
                .scaleEffect(commentsFlick != nil ? 0.93 : 1.0, anchor: .top)
                .offset(y: commentsFlick != nil ? geometry.safeAreaInsets.top : 0)
                .cornerRadius(commentsFlick != nil ? 16 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: commentsFlick != nil)
                .onChange(of: currentIndex) { newIndex in
                    onIndexChange(newIndex)
                }
                .ignoresSafeArea()

                if doubleTapHeartVisible {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 20)
                        .scaleEffect(doubleTapHeartVisible ? 1.2 : 0.5)
                        .opacity(doubleTapHeartVisible ? 1 : 0)
                        .transition(.scale.combined(with: .opacity))
                        .id(doubleTapHeartID)
                        .allowsHitTesting(false)
                }

                FlicksTopControls(
                    showSearchBar: $showSearchBar,
                    searchText: $searchText,
                    flicksMuted: $flicksMuted,
                    captionsEnabled: $captionsEnabled,
                    showUI: showUI
                )

                UIKitFlicksProgressRail(
                    count: flicksCount,
                    currentIndex: $currentIndex,
                    reduceMotion: reduceMotion,
                    onSelect: onProgressRailSelect
                )
                .frame(width: 24)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(showUI)
                .opacity(showUI ? 1 : 0)

                if isLoadingMore {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Loading more...")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding()
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }
}
