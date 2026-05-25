//
//  EffectPickerView.swift
//  MyChannel
//
//  ✨ EFFECT PICKER VIEW
//  Browse and apply AR effects and filters
//

import SwiftUI

struct EffectPickerView: View {
    @Binding var selectedEffect: AREffect?
    let onDismiss: () -> Void
    
    // Mock effects
    private let effects: [AREffect] = [
        AREffect(name: "Natural", category: .filter, thumbnailURL: ""),
        AREffect(name: "Vivid", category: .filter, thumbnailURL: ""),
        AREffect(name: "Dramatic", category: .filter, thumbnailURL: ""),
        AREffect(name: "Beauty", category: .beauty, thumbnailURL: ""),
        AREffect(name: "Smooth", category: .beauty, thumbnailURL: ""),
        AREffect(name: "Glow", category: .beauty, thumbnailURL: ""),
        AREffect(name: "Vintage", category: .filter, thumbnailURL: ""),
        AREffect(name: "B&W", category: .filter, thumbnailURL: "")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Effects & Filters")
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
            
            // Effects grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(effects) { effect in
                        EffectCard(
                            effect: effect,
                            isSelected: selectedEffect?.id == effect.id,
                            onTap: {
                                selectedEffect = effect
                                HapticManager.shared.impact(style: .medium)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxHeight: 500)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
        )
    }
}

struct EffectCard: View {
    let effect: AREffect
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 3)
                        )
                    
                    // Effect preview (mock)
                    Image(systemName: iconForCategory(effect.category))
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                Text(effect.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func iconForCategory(_ category: AREffect.EffectCategory) -> String {
        switch category {
        case .filter: return "camera.filters"
        case .beauty: return "star.fill"
        case .face: return "face.smiling"
        case .background: return "photo"
        case .animated: return "cpu"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        EffectPickerView(
            selectedEffect: .constant(nil as AREffect?),
            onDismiss: {}
        )
    }
}

