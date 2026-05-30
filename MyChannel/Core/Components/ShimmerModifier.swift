import SwiftUI

/// Phase 74: Shimmer Skeleton Loaders
/// Advanced SwiftUI modifier that applies an animated shimmering gradient over any view.
public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .modifier(
                AnimatedMask(phase: phase)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

/// A mask that creates the shimmer effect
struct AnimatedMask: AnimatableModifier {
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: max(0, phase - 0.2)),
                            .init(color: .black, location: phase),
                            .init(color: .clear, location: min(1, phase + 0.2))
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
    }
}

extension View {
    /// Applies a shimmering skeleton animation to the view
    @ViewBuilder
    func shimmer(isActive: Bool) -> some View {
        if isActive {
            self.modifier(ShimmerModifier())
        } else {
            self
        }
    }
    
    /// Applies a shimmering skeleton animation to the view
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}
