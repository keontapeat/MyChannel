//
//  ThemeCustomizationService.swift
//  MyChannel
//
//  Dark/Light Mode - Theme customization
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ThemeCustomizationService: ObservableObject {
    static let shared = ThemeCustomizationService()
    
    @Published private(set) var currentTheme: AppTheme = .system
    @Published private(set) var accentColor: AccentColor = .cyan
    
    enum AppTheme: String, CaseIterable, Codable {
        case light
        case dark
        case system
        
        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    enum AccentColor: String, CaseIterable, Codable {
        case cyan
        case blue
        case purple
        case green
        case orange
        case pink
        case red
        
        var color: Color {
            switch self {
            case .cyan: return .cyan
            case .blue: return .blue
            case .purple: return .purple
            case .green: return .green
            case .orange: return .orange
            case .pink: return .pink
            case .red: return .red
            }
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "command_center_theme"
    private let accentKey = "command_center_accent"
    
    private init() {
        loadTheme()
    }
    
    func loadTheme() {
        if let themeRaw = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
        }
        
        if let accentRaw = userDefaults.string(forKey: accentKey),
           let accent = AccentColor(rawValue: accentRaw) {
            accentColor = accent
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: themeKey)
    }
    
    func setAccentColor(_ accent: AccentColor) {
        accentColor = accent
        userDefaults.set(accent.rawValue, forKey: accentKey)
    }
}
