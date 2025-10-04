//
//  FlicksGestureOverlay.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

// MARK: - 🔥 Professional Flicks Gesture Overlay
struct FlicksGestureOverlay: View {
    let video: Video
    let geometry: GeometryProxy
    let onDoubleTap: (CGPoint) -> Void
    let onSingleTap: () -> Void
    let onLongPress: () -> Void
    
    // State for gesture recognition
    @State private var lastTapTime: Date?
    @State private var tapLocation: CGPoint = .zero
    @State private var longPressActive = false
    
    // Constants
    private let doubleTapThreshold: TimeInterval = 0.5
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .simultaneousGesture(
                // Single/Double Tap Gesture
                TapGesture(count: 1)
                    .onEnded { _ in
                        handleTap()
                    }
            )
            .simultaneousGesture(
                // Long Press Gesture
                LongPressGesture(minimumDuration: 0.5)
                    .onChanged { _ in
                        if !longPressActive {
                            longPressActive = true
                            onLongPress()
                        }
                    }
                    .onEnded { _ in
                        longPressActive = false
                    }
            )
            .simultaneousGesture(
                // Location tracking
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        tapLocation = value.location
                    }
            )
    }
    
    private func handleTap() {
        let now = Date()
        
        if let lastTap = lastTapTime,
           now.timeIntervalSince(lastTap) < doubleTapThreshold {
            // Double tap detected
            onDoubleTap(tapLocation)
            lastTapTime = nil // Reset to prevent triple tap
        } else {
            // Potential single tap - wait to see if double tap follows
            lastTapTime = now
            
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapThreshold) {
                if let storedTapTime = lastTapTime,
                   storedTapTime == now {
                    // Single tap confirmed
                    onSingleTap()
                    lastTapTime = nil
                }
            }
        }
    }
}

#Preview {
    GeometryReader { geometry in
        FlicksGestureOverlay(
            video: Video.sampleVideos.first!,
            geometry: geometry,
            onDoubleTap: { location in
                print("Double tap at: \(location)")
            },
            onSingleTap: {
                print("Single tap")
            },
            onLongPress: {
                print("Long press")
            }
        )
    }
    .frame(width: 300, height: 500)
    .background(Color.gray.opacity(0.3))
    .preferredColorScheme(.dark)
}