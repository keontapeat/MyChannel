//
//  OnePersonStudioView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🎬 ONE-PERSON ANIMATION STUDIO - Everything in one place!
//  Compete with Disney/Pixar SOLO! 🔥
//

import SwiftUI
import UIKit

// MARK: - Stub Types (TODO: Implement full types)
struct CompleteAnimationToolkit {
    static let shared = CompleteAnimationToolkit()
    private init() {}
    
    var projects: [AnimationProject] = []
    var characterLibrary: [CharacterAsset] = []
    var propLibrary: [String] = []
    
    struct EnvironmentGenerator {
        static let presets: [BackgroundPreset] = []
    }
    
    struct AudioSuite {
        static let categories: [SoundEffectCategory] = SoundEffectCategory.allCases
        static let soundEffects: [String] = [] // Placeholder
    }
    
    struct EffectsSuite {
        static let presets: [TransitionPreset] = []
        static let particleEffects: [String] = [] // Placeholder
        static let lightingPresets: [String] = [] // Placeholder
    }
    
    struct VideoEditor {
        static let presets: [ColorGradePreset] = []
        static let transitions: [TransitionPreset] = []
        static let colorGrades: [ColorGradePreset] = []
    }
    
    struct ExportSuite {
        static let formats: [ExportFormat] = ExportFormat.allCases
    }
}

struct SelfImprovingAISystem {
    static let shared = SelfImprovingAISystem()
    private init() {}
    
    var currentQualityScore: Double = 85.0
    var totalGenerations: Int = 1247
    var successRate: Double = 0.92
    var averageUserRating: Double = 4.7
    
    func getImprovementStatus() -> String {
        return "Learning from user interactions..."
    }
}

struct AnimationProject: Identifiable {
    let id: String
    let name: String
    let modified: Date = Date()
}

struct CharacterAsset: Identifiable {
    let id: String
    let name: String
    let thumbnail: UIImage? = nil
}

struct BackgroundPreset: Identifiable {
    let id: String
    let name: String
    let thumbnail: String = ""
}

enum SoundEffectCategory: String, CaseIterable {
    case action, comedy, drama, horror, sciFi
    
    var name: String {
        rawValue.capitalized
    }
    
    var sounds: Int {
        // Placeholder - return random count for each category
        switch self {
        case .action: return 1250
        case .comedy: return 850
        case .drama: return 600
        case .horror: return 450
        case .sciFi: return 320
        }
    }
}

struct TransitionPreset: Identifiable {
    let id: String
    let name: String
}

struct ColorGradePreset: Identifiable {
    let id: String
    let name: String
}

enum ExportFormat: String, CaseIterable {
    case mp4, mov, gif, pngSequence
    
    var name: String {
        switch self {
        case .mp4: return "MP4"
        case .mov: return "QuickTime"
        case .gif: return "GIF"
        case .pngSequence: return "PNG Sequence"
        }
    }
    
    var resolution: ExportResolution {
        switch self {
        case .mp4, .mov: return ExportResolution(dimensions: "1920x1080")
        case .gif: return ExportResolution(dimensions: "1280x720")
        case .pngSequence: return ExportResolution(dimensions: "3840x2160")
        }
    }
}

struct ExportResolution {
    let dimensions: String
}

struct OnePersonStudioView: View {
    // Note: These are singleton structs, accessed directly when needed
    private let toolkit = CompleteAnimationToolkit.shared
    private let selfImproving = SelfImprovingAISystem.shared
    
    @State private var selectedTool: StudioTool = .dashboard
    @State private var showingNewProject = false
    
    enum StudioTool: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case characters = "Characters"
        case environments = "Environments"
        case animation = "Animation"
        case audio = "Audio"
        case effects = "Effects"
        case editing = "Editing"
        case export = "Export"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .characters: return "person.3.fill"
            case .environments: return "photo.on.rectangle"
            case .animation: return "figure.walk.motion"
            case .audio: return "waveform"
            case .effects: return "star.fill"
            case .editing: return "film"
            case .export: return "square.and.arrow.up"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.1),
                        AppTheme.Colors.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tool Selector
                    toolSelector
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch selectedTool {
                            case .dashboard:
                                dashboardView
                            case .characters:
                                charactersView
                            case .environments:
                                environmentsView
                            case .animation:
                                animationView
                            case .audio:
                                audioView
                            case .effects:
                                effectsView
                            case .editing:
                                editingView
                            case .export:
                                exportView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("🎬 One-Person Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Label("New Project", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet()
        }
    }
    
    // MARK: - Tool Selector
    
    private var toolSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StudioTool.allCases) { tool in
                    StudioToolButton(
                        title: tool.rawValue,
                        icon: tool.icon,
                        isSelected: selectedTool == tool
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTool = tool
                        }
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Dashboard View
    
    private var dashboardView: some View {
        VStack(spacing: 24) {
            // AI Quality Status
            aiQualityCard
            
            // Quick Start
            quickStartCard
            
            // Recent Projects
            recentProjectsSection
            
            // Toolkit Overview
            toolkitOverviewCard
        }
    }
    
    private var aiQualityCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Quality Status")
                        .font(.system(size: 20, weight: .bold))
                    Text("Improving every day")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(selfImproving.getImprovementStatus())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
            }
            
            // Quality Meter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality Score")
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(Int(selfImproving.currentQualityScore))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
                
                ProgressView(value: selfImproving.currentQualityScore, total: 100)
                    .tint(.green)
            }
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SimpleStudioStatCard(title: "Generations", value: "\(selfImproving.totalGenerations)", icon: "star.fill")
                SimpleStudioStatCard(title: "Success Rate", value: "\(Int(selfImproving.successRate * 100))%", icon: "checkmark.circle")
                SimpleStudioStatCard(title: "Avg Rating", value: String(format: "%.1f", selfImproving.averageUserRating), icon: "star.fill")
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start")
                .font(.system(size: 20, weight: .bold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickStartButton(
                    title: "New Character",
                    icon: "person.badge.plus",
                    color: .blue
                ) {
                    selectedTool = .characters
                }
                
                QuickStartButton(
                    title: "Generate Scene",
                    icon: "photo.on.rectangle.angled",
                    color: .green
                ) {
                    selectedTool = .environments
                }
                
                QuickStartButton(
                    title: "Add Voice",
                    icon: "waveform",
                    color: .orange
                ) {
                    selectedTool = .audio
                }
                
                QuickStartButton(
                    title: "Apply Effects",
                    icon: "star.fill",
                    color: .purple
                ) {
                    selectedTool = .effects
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Projects")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button("View All") {}
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            if toolkit.projects.isEmpty {
                EmptyProjectsView()
            } else {
                ForEach(toolkit.projects.prefix(3)) { project in
                    ProjectCard(project: project)
                }
            }
        }
    }
    
    private var toolkitOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Assets")
                .font(.system(size: 20, weight: .bold))
            
            AssetCounter(title: "Characters", count: toolkit.characterLibrary.count, icon: "person.fill", color: .blue)
            AssetCounter(title: "Backgrounds", count: 50, icon: "photo.fill", color: .green)
            AssetCounter(title: "Props", count: toolkit.propLibrary.count, icon: "cube.fill", color: .orange)
            AssetCounter(title: "Sound Effects", count: 10000, icon: "waveform", color: .purple)
            AssetCounter(title: "Music Tracks", count: 5000, icon: "music.note", color: .pink)
            AssetCounter(title: "Animations", count: 200, icon: "figure.walk", color: .cyan)
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    // MARK: - Characters View
    
    private var charactersView: some View {
        VStack(spacing: 24) {
            // Create Character Card
            createCharacterCard
            
            // Character Library
            characterLibrarySection
        }
    }
    
    private var createCharacterCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create New Character")
                        .font(.system(size: 20, weight: .bold))
                    Text("AI-powered character generation")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("From Text") {}
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                
                Button("From Photo") {}
                    .buttonStyle(PrimaryButtonStyle(color: .green))
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    private var characterLibrarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Character Library")
                .font(.system(size: 20, weight: .bold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(toolkit.characterLibrary) { character in
                    CharacterCard(character: character)
                }
            }
        }
    }
    
    // MARK: - Environments View
    
    private var environmentsView: some View {
        VStack(spacing: 24) {
            Text("Environments & Backgrounds")
                .font(.system(size: 24, weight: .bold))
            
            // Environment presets
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(CompleteAnimationToolkit.EnvironmentGenerator.presets, id: \.name) { preset in
                    EnvironmentCard(preset: preset)
                }
            }
        }
    }
    
    // MARK: - Animation View
    
    private var animationView: some View {
        VStack(spacing: 24) {
            Text("Animation Library")
                .font(.system(size: 24, weight: .bold))
            
            // Animation categories
            ForEach(["Movement", "Gestures", "Emotions", "Combat", "Special"], id: \.self) { category in
                AnimationCategorySection(category: category)
            }
        }
    }
    
    // MARK: - Audio View
    
    private var audioView: some View {
        VStack(spacing: 24) {
            // Voice Generator
            voiceGeneratorCard
            
            // Sound Effects
            soundEffectsSection
            
            // Music Generator
            musicGeneratorCard
        }
    }
    
    private var voiceGeneratorCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Voice Generator")
                        .font(.system(size: 20, weight: .bold))
                    Text("Professional voice acting")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button("Generate Voice") {}
                .buttonStyle(PrimaryButtonStyle(color: .orange))
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    private var soundEffectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sound Effects Library")
                .font(.system(size: 20, weight: .bold))
            
            Text("10,000+ professional sound effects")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CompleteAnimationToolkit.AudioSuite.categories, id: \.rawValue) { category in
                    SoundCategoryCard(category: category)
                }
            }
        }
    }
    
    private var musicGeneratorCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundColor(.pink)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Music Generator")
                        .font(.system(size: 20, weight: .bold))
                    Text("Custom soundtracks for your animations")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button("Generate Music") {}
                .buttonStyle(PrimaryButtonStyle(color: .pink))
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    // MARK: - Effects View
    
    private var effectsView: some View {
        VStack(spacing: 24) {
            Text("Visual Effects")
                .font(.system(size: 24, weight: .bold))
            
            // Particle Effects
            effectCategoryCard(title: "Particle Effects", effects: CompleteAnimationToolkit.EffectsSuite.particleEffects, color: .purple)
            
            // Lighting
            effectCategoryCard(title: "Lighting Presets", effects: CompleteAnimationToolkit.EffectsSuite.lightingPresets, color: .yellow)
        }
    }
    
    private func effectCategoryCard(title: String, effects: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(effects, id: \.self) { effect in
                    EffectChip(name: effect, color: color)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    // MARK: - Editing View
    
    private var editingView: some View {
        VStack(spacing: 24) {
            Text("Video Editing Suite")
                .font(.system(size: 24, weight: .bold))
            
            // Transitions
            transitionsCard
            
            // Color Grading
            colorGradingCard
        }
    }
    
    private var transitionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transitions")
                .font(.system(size: 20, weight: .bold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CompleteAnimationToolkit.VideoEditor.transitions, id: \.name) { transition in
                    TransitionCard(transition: transition)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    private var colorGradingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Grading")
                .font(.system(size: 20, weight: .bold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CompleteAnimationToolkit.VideoEditor.colorGrades, id: \.name) { grade in
                    ColorGradeCard(grade: grade)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    // MARK: - Export View
    
    private var exportView: some View {
        VStack(spacing: 24) {
            Text("Export & Publish")
                .font(.system(size: 24, weight: .bold))
            
            // Export Formats
            exportFormatsCard
            
            // Quick Publish
            publishCard
        }
    }
    
    private var exportFormatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Formats")
                .font(.system(size: 20, weight: .bold))
            
            ForEach(CompleteAnimationToolkit.ExportSuite.formats, id: \.name) { format in
                ExportFormatRow(format: format)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
    
    private var publishCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("Publish to MyChannel")
                .font(.system(size: 20, weight: .bold))
            
            Text("Share your animation with the world")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button("Publish Now") {}
                .buttonStyle(PrimaryButtonStyle(color: AppTheme.Colors.primary))
        }
        .padding(32)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
    }
}

// MARK: - Supporting Views

struct StudioToolButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.Colors.primary : Color.clear)
            .cornerRadius(12)
        }
    }
}

struct SimpleStudioStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
}

struct QuickStartButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(color.opacity(0.1))
            .cornerRadius(16)
        }
    }
}

struct AssetCounter: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyProjectsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No projects yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Start your first animation project")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(16)
    }
}

struct ProjectCard: View {
    let project: AnimationProject
    
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.primary.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "film")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.primary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.system(size: 16, weight: .semibold))
                Text("Modified \(project.modified, style: .relative) ago")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
}

struct CharacterCard: View {
    let character: CharacterAsset
    
    var body: some View {
        VStack(spacing: 12) {
            if let thumbnail = character.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Text(character.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
}

struct EnvironmentCard: View {
    let preset: BackgroundPreset
    
    var body: some View {
        VStack(spacing: 12) {
            Text(preset.thumbnail)
                .font(.system(size: 48))
            Text(preset.name)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
}

struct AnimationCategorySection: View {
    let category: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.system(size: 18, weight: .bold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { _ in
                        AnimationChip(name: "Animation")
                    }
                }
            }
        }
    }
}

struct AnimationChip: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surface)
            .cornerRadius(20)
    }
}

struct SoundCategoryCard: View {
    let category: SoundEffectCategory
    
    var body: some View {
        VStack(spacing: 8) {
            Text(category.name)
                .font(.system(size: 14, weight: .semibold))
            Text("\(category.sounds) sounds")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

struct EffectChip: View {
    let name: String
    let color: Color
    
    var body: some View {
        Text(name)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
    }
}

struct TransitionCard: View {
    let transition: TransitionPreset
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 24))
                .foregroundColor(.blue)
            Text(transition.name)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

struct ColorGradeCard: View {
    let grade: ColorGradePreset
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            Text(grade.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

struct ExportFormatRow: View {
    let format: ExportFormat
    
    var body: some View {
        HStack {
            Image(systemName: "film")
                .foregroundColor(.blue)
            Text(format.name)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Text(format.resolution.dimensions)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("New Project")
                .navigationTitle("New Project")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    OnePersonStudioView()
}

