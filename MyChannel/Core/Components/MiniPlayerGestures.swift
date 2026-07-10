//
//  MiniPlayerGestures.swift
//  MyChannel
//
//  Extracted from FloatingMiniPlayer — gesture helpers and handlers.
//

import SwiftUI

// MARK: - Gesture Handling

extension FloatingMiniPlayer {

    func freeFloatingDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($dragState) { value, state, transaction in
                state = value.translation
                transaction.animation = .interactiveSpring()

                if !isDragging {
                    Task { @MainActor in
                        isDragging = true
                        lastPosition = position
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .onEnded { value in
                isDragging = false

                let finalX = lastPosition.x + value.translation.width
                let finalY = lastPosition.y + value.translation.height

                let halfWidth = playerSize.width / 2
                let halfHeight = playerSize.height / 2
                let minX = halfWidth + 10
                let maxX = geometry.size.width - halfWidth - 10
                let minY = halfHeight + 50
                let maxY = geometry.size.height - halfHeight - 100

                let snapX: CGFloat
                let snapY: CGFloat

                let centerX = geometry.size.width / 2
                if finalX < centerX {
                    snapX = minX
                } else {
                    snapX = maxX
                }

                let verticalSwipe = abs(value.translation.height)
                let horizontalSwipe = abs(value.translation.width)

                if verticalSwipe > 150 && value.translation.height > 0 && verticalSwipe > horizontalSwipe {
                    globalPlayer.closePlayer()
                    HapticManager.shared.impact(style: .heavy)
                    return
                }

                if verticalSwipe > 100 && value.translation.height < 0 && verticalSwipe > horizontalSwipe {
                    globalPlayer.expandPlayer()
                    globalPlayer.expandPlayer()
                    HapticManager.shared.impact(style: .medium)
                    return
                }

                if finalY < minY + 50 {
                    snapY = minY
                } else if finalY > maxY - 50 {
                    snapY = maxY
                } else {
                    snapY = max(minY, min(maxY, finalY))
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                    position = CGPoint(x: snapX, y: snapY)
                    lastPosition = position
                }

                HapticManager.shared.impact(style: .light)
            }
    }

    var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                if abs(horizontalDistance) > verticalDistance {
                    if horizontalDistance > 50 {
                        navigateToPreviousVideo()
                    } else if horizontalDistance < -50 {
                        navigateToNextVideo()
                    }
                }
            }
    }

    var pinchToResizeGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    HapticManager.shared.impact(style: .light)
                }

                let baseWidth: CGFloat = 140
                let baseHeight: CGFloat = 78
                let scale = min(max(0.7, value), 1.5)

                playerSize = CGSize(
                    width: baseWidth * scale,
                    height: baseHeight * scale
                )
            }
            .onEnded { _ in
                isResizing = false
                let baseWidth: CGFloat = 140
                let baseHeight: CGFloat = 78
                let currentScale = playerSize.width / baseWidth

                let targetScale: CGFloat
                if currentScale < 0.85 {
                    targetScale = 0.7
                } else if currentScale > 1.15 {
                    targetScale = 1.5
                } else {
                    targetScale = 1.0
                }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)) {
                    playerSize = CGSize(
                        width: baseWidth * targetScale,
                        height: baseHeight * targetScale
                    )
                }
                HapticManager.shared.impact(style: .medium)
            }
    }
}

// MARK: - Actions

extension FloatingMiniPlayer {

    func expandPlayer() {
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8)) {
            globalPlayer.expandPlayer()
        }
        HapticManager.shared.impact(style: .medium)
    }

    func closePlayer() {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
            globalPlayer.closePlayer()
        }
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Gesture Handlers

extension FloatingMiniPlayer {

    func handleSingleTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.3 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now

        if tapCount == 1 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                if self.tapCount == 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.showingControls.toggle()
                    }
                    if self.showingControls {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.showingControls = false
                        }
                    }
                }
            }
        } else if tapCount == 2 {
            expandPlayer()
        }
    }

    func showSeekFeedback(isForward: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingControls = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls = false
            }
        }
    }

    func navigateToPreviousVideo() {
        globalPlayer.playPreviousVideo()
    }

    func navigateToNextVideo() {
        globalPlayer.playNextVideo()
    }
}
