//
//  EditingToolsBar.swift
//  MyChannel
//
//  🎨 EDITING TOOLS BAR
//  Professional editing tools for story creation
//

import SwiftUI

struct EditingToolsBar: View {
    @Binding var selectedTool: EditingTool
    let onTextAdd: () -> Void
    let onStickerAdd: () -> Void
    let onDrawingStart: () -> Void
    let onMusicAdd: () -> Void
    let onFilterAdd: () -> Void
    let onTemplateApply: () -> Void
    let onAIEnhance: () -> Void
    
    private let tools: [(tool: EditingTool, icon: String, action: () -> Void)] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                // Text tool
                EditingToolButton(
                    icon: "textformat",
                    title: "Text",
                    isSelected: selectedTool == .text
                ) {
                    selectedTool = .text
                    onTextAdd()
                }
                
                // Sticker tool
                EditingToolButton(
                    icon: "face.smiling",
                    title: "Sticker",
                    isSelected: selectedTool == .sticker
                ) {
                    selectedTool = .sticker
                    onStickerAdd()
                }
                
                // Drawing tool
                EditingToolButton(
                    icon: "scribble",
                    title: "Draw",
                    isSelected: selectedTool == .drawing
                ) {
                    selectedTool = .drawing
                    onDrawingStart()
                }
                
                // Music tool
                EditingToolButton(
                    icon: "music.note",
                    title: "Music",
                    isSelected: selectedTool == .music
                ) {
                    selectedTool = .music
                    onMusicAdd()
                }
                
                // Filter tool
                EditingToolButton(
                    icon: "camera.filters",
                    title: "Filter",
                    isSelected: selectedTool == .filter
                ) {
                    selectedTool = .filter
                    onFilterAdd()
                }
                
                // Template tool
                EditingToolButton(
                    icon: "square.grid.2x2",
                    title: "Template",
                    isSelected: selectedTool == .template
                ) {
                    selectedTool = .template
                    onTemplateApply()
                }
                
                // AI tool
                EditingToolButton(
                    icon: "star.fill",
                    title: "AI",
                    isSelected: selectedTool == .ai,
                    gradient: true
                ) {
                    selectedTool = .ai
                    onAIEnhance()
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
        .background(
            Blur(style: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tool Button
struct EditingToolButton: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    var gradient: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    if gradient {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                    } else {
                        Circle()
                            .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(EditingToolsScaleButtonStyle())
    }
}

// MARK: - EditingTools-Specific Button Style

struct EditingToolsScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Blur View
struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        EditingToolsBar(
            selectedTool: .constant(.text),
            onTextAdd: {},
            onStickerAdd: {},
            onDrawingStart: {},
            onMusicAdd: {},
            onFilterAdd: {},
            onTemplateApply: {},
            onAIEnhance: {}
        )
    }
}

