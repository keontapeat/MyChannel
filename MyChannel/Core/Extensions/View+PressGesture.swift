//
//  View+PressGesture.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

extension View {
    func onPressGesture(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        self.modifier(PressGestureModifier(onPress: onPress, onRelease: onRelease))
    }
}

struct PressGestureModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onRelease()
                        }
                    }
            )
    }
}