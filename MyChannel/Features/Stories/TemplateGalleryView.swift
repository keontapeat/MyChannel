//
//  TemplateGalleryView.swift
//  MyChannel
//
//  📋 TEMPLATE GALLERY VIEW
//  Trending story templates for quick creation
//

import SwiftUI

struct TemplateGalleryView: View {
    let onTemplateSelect: (StoryTemplate) -> Void
    let onDismiss: () -> Void
    
    // Mock templates
    private let templates: [StoryTemplate] = [
        StoryTemplate(
            name: "Minimal",
            category: .minimal,
            thumbnailURL: "",
            textStyle: StoryTemplate.TemplateTextStyle(
                font: .modern,
                color: .white,
                backgroundStyle: .none
            ),
            effect: nil,
            layout: nil
        ),
        StoryTemplate(
            name: "Bold",
            category: .bold,
            thumbnailURL: "",
            textStyle: StoryTemplate.TemplateTextStyle(
                font: .bold,
                color: .yellow,
                backgroundStyle: .solid
            ),
            effect: nil,
            layout: nil
        ),
        StoryTemplate(
            name: "Neon",
            category: .creative,
            thumbnailURL: "",
            textStyle: StoryTemplate.TemplateTextStyle(
                font: .neon,
                color: .pink,
                backgroundStyle: .gradient
            ),
            effect: nil,
            layout: nil
        ),
        StoryTemplate(
            name: "Classic",
            category: .minimal,
            thumbnailURL: "",
            textStyle: StoryTemplate.TemplateTextStyle(
                font: .classic,
                color: .white,
                backgroundStyle: .outline
            ),
            effect: nil,
            layout: nil
        )
    ]
    
    @State private var selectedCategory: StoryTemplate.TemplateCategory = .trending
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Templates")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            
            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(StoryTemplate.TemplateCategory.allCases, id: \.self) { category in
                        CategoryTab(
                            title: category.rawValue.capitalized,
                            isSelected: selectedCategory == category,
                            onTap: {
                                selectedCategory = category
                                HapticManager.shared.impact(style: .light)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
            
            // Templates grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(templates) { template in
                        TemplateCard(
                            template: template,
                            onTap: {
                                onTemplateSelect(template)
                                HapticManager.shared.impact(style: .medium)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxHeight: 600)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
        )
    }
}

struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(TemplateScaleButtonStyle())
    }
}

struct TemplateCard: View {
    let template: StoryTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Template preview
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                    
                    // Preview text with template style
                    if let textStyle = template.textStyle {
                        Text("Aa")
                            .font(textStyle.font.systemFont)
                            .foregroundColor(textStyle.color)
                            .padding(12)
                            .background(
                                backgroundForStyle(textStyle.backgroundStyle)
                            )
                    }
                }
                
                // Template name
                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(TemplateScaleButtonStyle())
    }
    
    @ViewBuilder
    private func backgroundForStyle(_ style: TextBackgroundStyle) -> some View {
        switch style {
        case .none:
            Color.clear
        case .solid:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        case .gradient:
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .outline:
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
        }
    }
}

// MARK: - Template-Specific Button Style

struct TemplateScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension StoryTemplate.TemplateCategory: CaseIterable {
    static var allCases: [StoryTemplate.TemplateCategory] {
        [.trending, .minimal, .bold, .creative, .business]
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        TemplateGalleryView(
            onTemplateSelect: { _ in },
            onDismiss: {}
        )
    }
}

