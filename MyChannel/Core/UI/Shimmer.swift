import SwiftUI

struct Shimmer: ViewModifier {
    var active: Bool
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    ZStack {
                        if active {
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white.opacity(0.0), location: 0.35),
                                    .init(color: .white.opacity(0.6), location: 0.5),
                                    .init(color: .white.opacity(0.0), location: 0.65)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .rotationEffect(.degrees(25))
                            .offset(x: phase * geo.size.width * 2)
                            .onAppear { animate() }
                            .allowsHitTesting(false)
                        }
                    }
                }
                .blendMode(.plusLighter)
            )
    }
    
    private func animate() {
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            phase = 1.2
        }
    }
}

extension View {
    func shimmer(active: Bool) -> some View {
        modifier(Shimmer(active: active))
    }
}

#Preview {
    VStack(spacing: 16) {
        RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3)).frame(height: 80).shimmer(active: true)
        RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3)).frame(height: 80).shimmer(active: true)
    }
    .padding()
    .background(AppTheme.Colors.background)
}