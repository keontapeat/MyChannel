//
//  ButtonStyles.swift
//  MyChannel
//
//  Shared button styles used across the app
//

import SwiftUI

// MARK: - Scale Button Style
/// A button style that scales down slightly when pressed for a tactile feel
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.95
    var dampingFraction: CGFloat = 0.7
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: dampingFraction), value: configuration.isPressed)
    }
}

// MARK: - Bounce Button Style
/// A button style with more pronounced bounce animation
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Glow Button Style
/// A button style that adds a subtle glow when pressed
struct GlowButtonStyle: ButtonStyle {
    var glowColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: configuration.isPressed ? glowColor.opacity(0.5) : .clear, radius: 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Button("Scale Button") {}
            .buttonStyle(ScaleButtonStyle())
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        
        Button("Bounce Button") {}
            .buttonStyle(BounceButtonStyle())
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        
        Button("Glow Button") {}
            .buttonStyle(GlowButtonStyle(glowColor: .purple))
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
    .padding()
}




