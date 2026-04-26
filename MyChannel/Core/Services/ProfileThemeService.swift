//
//  ProfileThemeService.swift
//  MyChannel
//
//  Phase 241: Profile Themes & Visual Identity.
//  Custom color palettes, font choices, layout templates,
//  dark/light theme presets, brand-consistent visual identity.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation
import SwiftUI

// MARK: - Models

struct ProfileTheme: Codable, Identifiable {
    let id: String
    let creatorId: String
    let name: String
    let palette: ThemePalette
    let fontName: String
    let layoutTemplate: LayoutTemplate
    let isPreset: Bool
    let createdAt: Date

    struct ThemePalette: Codable {
        let primaryHex: String
        let secondaryHex: String
        let accentHex: String
        let backgroundHex: String
        let textHex: String
    }

    enum LayoutTemplate: String, Codable {
        case standard, compact, cinematic, minimal, magazine
    }
}

struct ThemePreset: Codable, Identifiable {
    let id: String
    let name: String
    let palette: ProfileTheme.ThemePalette
    let previewURL: String?
}

// MARK: - Service

@MainActor
final class ProfileThemeService: ObservableObject {
    static let shared = ProfileThemeService()
    private init() {}

    @Published private(set) var currentTheme: ProfileTheme?
    @Published private(set) var presets: [ThemePreset] = []
    @Published private(set) var customThemes: [ProfileTheme] = []
    @Published var isApplying: Bool = false

    func fetchPresets() async throws {
        guard AppConfig.Features.enableProfileThemes else { return }
        struct Req: Encodable { let task: String }
        struct RawPreset: Decodable { let id: String; let name: String; let primary: String; let secondary: String; let accent: String; let background: String; let text: String; let preview: String? }
        struct Raw: Decodable { let presets: [RawPreset]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_theme_presets")
        )
        presets = (r.presets ?? []).map {
            ThemePreset(id: $0.id, name: $0.name,
                        palette: ProfileTheme.ThemePalette(primaryHex: $0.primary, secondaryHex: $0.secondary,
                                                             accentHex: $0.accent, backgroundHex: $0.background, textHex: $0.text),
                        previewURL: $0.preview)
        }
    }

    func applyTheme(creatorId: String, presetId: String) async throws -> ProfileTheme {
        guard AppConfig.Features.enableProfileThemes else {
            return ProfileTheme(id: "", creatorId: creatorId, name: "Default",
                                palette: ProfileTheme.ThemePalette(primaryHex: "#FF0000", secondaryHex: "#FF6B6B", accentHex: "#FFD700", backgroundHex: "#000000", textHex: "#FFFFFF"),
                                fontName: "System", layoutTemplate: .standard, isPreset: true, createdAt: Date())
        }
        isApplying = true
        defer { isApplying = false }
        struct Req: Encodable { let task: String; let creatorId: String; let presetId: String }
        struct Raw: Decodable { let id: String; let name: String; let primary: String; let secondary: String; let accent: String; let background: String; let text: String; let font: String; let layout: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "apply_theme", creatorId: creatorId, presetId: presetId)
        )
        let theme = ProfileTheme(id: r.id, creatorId: creatorId, name: r.name,
                                   palette: ProfileTheme.ThemePalette(primaryHex: r.primary, secondaryHex: r.secondary,
                                                                       accentHex: r.accent, backgroundHex: r.background, textHex: r.text),
                                   fontName: r.font, layoutTemplate: .init(rawValue: r.layout) ?? .standard,
                                   isPreset: true, createdAt: Date())
        currentTheme = theme
        return theme
    }

    func createCustomTheme(creatorId: String, name: String, palette: ProfileTheme.ThemePalette, font: String, layout: ProfileTheme.LayoutTemplate) async throws -> ProfileTheme {
        guard AppConfig.Features.enableProfileThemes else {
            return ProfileTheme(id: "", creatorId: creatorId, name: name, palette: palette,
                                fontName: font, layoutTemplate: layout, isPreset: false, createdAt: Date())
        }
        struct Req: Encodable { let task: String; let creatorId: String; let name: String; let primary: String; let secondary: String; let accent: String; let background: String; let text: String; let font: String; let layout: String }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "create_custom_theme", creatorId: creatorId, name: name,
                      primary: palette.primaryHex, secondary: palette.secondaryHex, accent: palette.accentHex,
                      background: palette.backgroundHex, text: palette.textHex, font: font, layout: layout.rawValue)
        )
        let theme = ProfileTheme(id: r.id, creatorId: creatorId, name: name, palette: palette,
                                   fontName: font, layoutTemplate: layout, isPreset: false, createdAt: Date())
        customThemes.append(theme)
        currentTheme = theme
        return theme
    }

    func fetchActiveTheme(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileThemes else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let id: String; let name: String; let primary: String; let secondary: String; let accent: String; let background: String; let text: String; let font: String; let layout: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_active_theme", creatorId: creatorId)
        )
        currentTheme = ProfileTheme(id: r.id, creatorId: creatorId, name: r.name,
                                      palette: ProfileTheme.ThemePalette(primaryHex: r.primary, secondaryHex: r.secondary,
                                                                          accentHex: r.accent, backgroundHex: r.background, textHex: r.text),
                                      fontName: r.font, layoutTemplate: .init(rawValue: r.layout) ?? .standard,
                                      isPreset: false, createdAt: Date())
    }
}
