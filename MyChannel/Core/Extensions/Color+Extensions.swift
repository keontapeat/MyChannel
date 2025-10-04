//
//  Color+Extensions.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

// MARK: - Color Extensions
extension Color {
    // MARK: - Random Color
    static var random: Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
    
    // MARK: - Brightness Adjustments
    func lighter(by percentage: CGFloat = 30.0) -> Color {
        return self.adjust(by: abs(percentage) / 100)
    }
    
    func darker(by percentage: CGFloat = 30.0) -> Color {
        return self.adjust(by: -1 * abs(percentage) / 100)
    }
    
    private func adjust(by percentage: CGFloat) -> Color {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let r = min(max(components[0] + percentage, 0), 1)
        let g = min(max(components[1] + percentage, 0), 1)
        let b = min(max(components[2] + percentage, 0), 1)
        let a = components.count > 3 ? components[3] : 1
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Notification Extension
extension NSNotification.Name {
    static let scrollToTopProfile = NSNotification.Name("scrollToTopProfile")
}

#Preview("Color Extensions Demo") {
    VStack(spacing: 20) {
        Text("Color Extensions Demo")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        // Hex colors
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color(hex: "FF6B6B"))
                .frame(width: 60, height: 60)
                .cornerRadius(12)
            
            Rectangle()
                .fill(Color(hex: "4ECDC4"))
                .frame(width: 60, height: 60)
                .cornerRadius(12)
            
            Rectangle()
                .fill(Color(hex: "45B7D1"))
                .frame(width: 60, height: 60)
                .cornerRadius(12)
        }
        
        // Random colors
        HStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.random)
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
            }
        }
        
        // Brightness adjustments
        VStack(spacing: 12) {
            Text("Brightness Adjustments")
                .font(.headline)
            
            let baseColor = Color(hex: "FF6B6B")
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(baseColor.darker(by: 40))
                    .frame(width: 40, height: 40)
                
                Rectangle()
                    .fill(baseColor.darker(by: 20))
                    .frame(width: 40, height: 40)
                
                Rectangle()
                    .fill(baseColor)
                    .frame(width: 40, height: 40)
                
                Rectangle()
                    .fill(baseColor.lighter(by: 20))
                    .frame(width: 40, height: 40)
                
                Rectangle()
                    .fill(baseColor.lighter(by: 40))
                    .frame(width: 40, height: 40)
            }
            .cornerRadius(8)
        }
        
        Spacer()
    }
    .padding()
}