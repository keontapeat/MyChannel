//
//  MiniPlayerGestureView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct MiniPlayerGestureView: View {
    let onTap: () -> Void
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        dragOffset = .zero
                        
                        // Determine swipe direction
                        if abs(value.translation.height) > abs(value.translation.width) {
                            if value.translation.height < -50 {
                                // Swipe up
                                onSwipeUp()
                            } else if value.translation.height > 50 {
                                // Swipe down
                                onSwipeDown()
                            }
                        }
                    }
            )
    }
}

#Preview {
    MiniPlayerGestureView(
        onTap: { print("Tapped") },
        onSwipeUp: { print("Swiped up") },
        onSwipeDown: { print("Swiped down") }
    )
    .frame(width: 200, height: 100)
    .background(Color.blue.opacity(0.3))
}