//
//  Color+Hex.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

extension Color {
    // MARK: - Hex Color Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Hex String Representation
    var hexString: String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Color Hex Extension")
            .font(AppTheme.Typography.title1)
        
        HStack(spacing: 16) {
            VStack {
                Rectangle()
                    .fill(Color(hex: "FF6B6B"))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                Text("#FF6B6B")
                    .font(AppTheme.Typography.caption)
            }
            
            VStack {
                Rectangle()
                    .fill(Color(hex: "4ECDC4"))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                Text("#4ECDC4")
                    .font(AppTheme.Typography.caption)
            }
            
            VStack {
                Rectangle()
                    .fill(Color(hex: "45B7D1"))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                Text("#45B7D1")
                    .font(AppTheme.Typography.caption)
            }
        }
        
        Text("Hex String: \(AppTheme.Colors.primary.hexString)")
            .font(AppTheme.Typography.caption)
            .foregroundColor(AppTheme.Colors.textSecondary)
    }
    .padding()
}