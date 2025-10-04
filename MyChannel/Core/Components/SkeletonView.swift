import SwiftUI

struct SkeletonView: View {
    var cornerRadius: CGFloat = 8
    var isActive: Bool = true
    var baseColor: Color = Color.gray.opacity(0.25)
    var highlightColor: Color = Color.gray.opacity(0.45)

    @State private var animationOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                baseColor
                if isActive {
                    LinearGradient(
                        gradient: Gradient(colors: [baseColor, highlightColor, baseColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(
                        Rectangle()
                            .fill(Color.white)
                            .offset(x: animationOffset * geometry.size.width)
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                            animationOffset = 2.0
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}


