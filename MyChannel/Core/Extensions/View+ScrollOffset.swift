//
//  View+ScrollOffset.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

extension View {
    func onScrollOffsetChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(ScrollOffsetModifier(onChange: action))
    }
}

struct ScrollOffsetModifier: ViewModifier {
    let onChange: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                onChange(value)
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}