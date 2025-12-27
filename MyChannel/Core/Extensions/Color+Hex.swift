//
//  Color+Hex.swift
//  MyChannel
//
//  Color extension for hex color support
//

import SwiftUI

extension Color {
    /// Initialize a Color from a hex string (non-optional, defaults to clear if invalid)
    init(hexString hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(.clear)
            return
        }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            self.init(.clear)
            return
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Initialize a Color from a hex string (optional version, returns nil if invalid)
    init?(hexOptional hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Convert Color to hex string
    func toHex() -> String? {
        #if os(macOS)
        guard let components = NSColor(self).cgColor.components else { return nil }
        #else
        guard let components = UIColor(self).cgColor.components else { return nil }
        #endif
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        let a = components.count >= 4 ? components[3] : 1.0
        
        if a == 1.0 {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(Float(r * 255)),
                         lroundf(Float(g * 255)),
                         lroundf(Float(b * 255)))
        } else {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(Float(r * 255)),
                         lroundf(Float(g * 255)),
                         lroundf(Float(b * 255)),
                         lroundf(Float(a * 255)))
        }
    }
}
