import SwiftUI

struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(AppTheme.AnimationPresets.spring, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Primary") {}
            .primaryButtonStyle()
            .buttonStyle(PressableScaleStyle())
        
        Button {
        } label: {
            Image(systemName: "heart.fill")
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.red, in: Circle())
        }
        .buttonStyle(PressableScaleStyle(scale: 0.92))
    }
    .padding()
    .background(AppTheme.Colors.background)
}