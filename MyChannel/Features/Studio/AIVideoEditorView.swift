//
//  AIVideoEditorView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct AIVideoEditorView: View {
    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var selectedEffect = "Auto-Color"
    
    let effects = ["Auto-Color", "Remove Silence", "Auto-Captions", "Smart Crop", "Enhance Audio"]
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 250)
                    
                    Image(systemName: "video.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("AI Editor Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(effects, id: \.self) { effect in
                                Button(action: {
                                    selectedEffect = effect
                                }) {
                                    Text(effect)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedEffect == effect ? AppTheme.Colors.primary : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedEffect == effect ? .white : AppTheme.Colors.textPrimary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if isProcessing {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(processingStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        Button(action: applyEffect) {
                            Text("Apply \(selectedEffect)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("AI Video Editor v2")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func applyEffect() {
        isProcessing = true
        processingStatus = "Applying \(selectedEffect)..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
            HapticManager.shared.impact(style: .medium)
        }
    }
}

#Preview {
    AIVideoEditorView()
}
