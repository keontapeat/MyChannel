//
//  AdvancedFeaturesMenu.swift
//  MyChannel
//
//  🚀 ADVANCED FEATURES MENU
//  Access to all nuclear features (AR, Green Screen, Multi-Clip, Voice Effects)
//

import SwiftUI

struct AdvancedFeaturesMenu: View {
    @ObservedObject var storyViewModel: UltimateStoryViewModel
    @StateObject private var arEngine = ARFaceFilterEngine()
    @StateObject private var greenScreenEngine = GreenScreenEngine()
    @StateObject private var multiClipEngine = MultiClipEngine()
    @StateObject private var voiceEngine = VoiceEffectsEngine()
    
    @Binding var isPresented: Bool
    @State private var selectedFeature: AdvancedFeature = .arFilters
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Feature tabs
                    featureTabs
                    
                    // Feature content
                    TabView(selection: $selectedFeature) {
                        ARFiltersView(engine: arEngine)
                            .tag(AdvancedFeature.arFilters)
                        
                        GreenScreenView(engine: greenScreenEngine, viewModel: storyViewModel)
                            .tag(AdvancedFeature.greenScreen)
                        
                        MultiClipView(engine: multiClipEngine)
                            .tag(AdvancedFeature.multiClip)
                        
                        VoiceEffectsView(engine: voiceEngine)
                            .tag(AdvancedFeature.voiceEffects)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Advanced Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var featureTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(AdvancedFeature.allCases) { feature in
                    FeatureTab(
                        feature: feature,
                        isSelected: selectedFeature == feature,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFeature = feature
                            }
                            HapticManager.shared.impact(style: .light)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Feature Tab
struct FeatureTab: View {
    let feature: AdvancedFeature
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: feature.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Text(feature.title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: feature.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40, height: 3)
                }
            }
            .frame(width: 80)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - AR Filters View
struct ARFiltersView: View {
    @ObservedObject var engine: ARFaceFilterEngine
    
    var body: some View {
        VStack {
            Text("🎭 AR Face Filters")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Real-time face tracking with AR effects")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 20)
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(engine.availableFilters) { filter in
                        ARFilterCard(filter: filter) {
                            engine.applyFilter(filter)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ARFilterCard: View {
    let filter: FaceFilter
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                    
                    Image(systemName: filter.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                Text(filter.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Green Screen View
struct GreenScreenView: View {
    @ObservedObject var engine: GreenScreenEngine
    @ObservedObject var viewModel: UltimateStoryViewModel
    
    var body: some View {
        VStack {
            Text("🎬 Green Screen")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Remove & replace background")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 20)
            
            // Background options
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(engine.availableBackgrounds) { bg in
                        BackgroundCard(background: bg) {
                            engine.selectedBackground = bg.type
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Quality settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quality")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Picker("Quality", selection: $engine.maskQuality) {
                        Text("Low").tag(GreenScreenEngine.MaskQuality.low)
                        Text("Medium").tag(GreenScreenEngine.MaskQuality.medium)
                        Text("High").tag(GreenScreenEngine.MaskQuality.high)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)
            }
        }
    }
}

struct BackgroundCard: View {
    let background: BackgroundOption
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                    
                    Image(systemName: background.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                Text(background.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Multi-Clip View
struct MultiClipView: View {
    @ObservedObject var engine: MultiClipEngine
    
    var body: some View {
        VStack {
            Text("🎬 Multi-Clip")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Stitch videos with transitions")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 20)
            
            if engine.clips.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Add clips to start")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button(action: {}) {
                        Text("Add Clip")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                // Clips timeline
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(engine.clips) { clip in
                            ClipCard(clip: clip, engine: engine)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

struct ClipCard: View {
    let clip: MultiClipVideoClip
    @ObservedObject var engine: MultiClipEngine
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 80)
                .overlay(
                    Image(systemName: "film")
                        .foregroundColor(.white.opacity(0.6))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Clip \(formatDuration(clip.duration))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Transition: \(clip.transition.rawValue)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Speed: \(String(format: "%.1fx", clip.speed))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: {
                engine.removeClip(clip.id)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }
}

// MARK: - Voice Effects View
struct VoiceEffectsView: View {
    @ObservedObject var engine: VoiceEffectsEngine
    
    var body: some View {
        VStack {
            Text("🎤 Voice Effects")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Transform your voice")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 20)
            
            ScrollView {
                // Voice effects
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(engine.availableEffects) { effect in
                        VoiceEffectCard(effect: effect.effect, name: effect.name, icon: effect.icon) {
                            engine.applyEffectRealtime(effect.effect)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Manual controls
                VStack(spacing: 20) {
                    ControlSlider(
                        title: "Pitch",
                        value: $engine.pitch,
                        range: -12...12,
                        icon: "tuningfork"
                    )
                    
                    ControlSlider(
                        title: "Speed",
                        value: $engine.speed,
                        range: 0.5...2.0,
                        icon: "speedometer"
                    )
                    
                    ControlSlider(
                        title: "Reverb",
                        value: $engine.reverb,
                        range: 0...100,
                        icon: "building.2"
                    )
                    
                    ControlSlider(
                        title: "Echo",
                        value: $engine.echo,
                        range: 0...100,
                        icon: "speaker.wave.2"
                    )
                }
                .padding(20)
            }
        }
    }
}

struct VoiceEffectCard: View {
    let effect: VoiceEffect
    let name: String
    let icon: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .red.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                    
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ControlSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.8))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Slider(value: $value, in: range)
                .tint(AppTheme.Colors.primary)
        }
    }
}

// MARK: - Advanced Feature Enum
enum AdvancedFeature: String, CaseIterable, Identifiable {
    case arFilters = "AR Filters"
    case greenScreen = "Green Screen"
    case multiClip = "Multi-Clip"
    case voiceEffects = "Voice Effects"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .arFilters: return "face.smiling"
        case .greenScreen: return "photo.on.rectangle.angled"
        case .multiClip: return "film.stack"
        case .voiceEffects: return "waveform"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .arFilters: return [.purple, .pink]
        case .greenScreen: return [.green, .blue]
        case .multiClip: return [.blue, .cyan]
        case .voiceEffects: return [.orange, .red]
        }
    }
}

#Preview {
    AdvancedFeaturesMenu(
        storyViewModel: UltimateStoryViewModel(),
        isPresented: .constant(true)
    )
}






