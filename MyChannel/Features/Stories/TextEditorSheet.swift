//
//  TextEditorSheet.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct TextEditorSheet: View {
    let onTextCreated: (CreateStoryViewModel.TextOverlay) -> Void
    
    @State private var text = ""
    @State private var selectedColor: Color = .white
    @State private var selectedBackgroundColor: Color = .clear
    @State private var selectedFontStyle: CreateStoryViewModel.TextOverlay.FontStyle = .bold
    @State private var backgroundGradient: [Color] = [.blue, .purple]
    @Environment(\.dismiss) private var dismiss
    
    private let colors: [Color] = [
        .white, .black, .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan
    ]
    
    private let gradients: [[Color]] = [
        [.blue, .purple],
        [.pink, .orange],
        [.green, .blue],
        [.red, .pink],
        [.yellow, .orange],
        [.purple, .blue],
        [.cyan, .blue],
        [.orange, .red]
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Text input area
                VStack(spacing: 16) {
                    ZStack {
                        // Background preview
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: backgroundGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 200)
                        
                        // Text preview
                        if text.isEmpty {
                            Text("Type your story...")
                                .font(selectedFontStyle.font)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text(text)
                                .font(selectedFontStyle.font)
                                .foregroundColor(selectedColor)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(
                                    selectedBackgroundColor == .clear ? nil : selectedBackgroundColor.opacity(0.8)
                                )
                                .cornerRadius(8)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Text input field
                    TextField("What's on your mind?", text: $text, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                // Font style selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Style")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CreateStoryViewModel.TextOverlay.FontStyle.allCases, id: \.self) { style in
                                Button(action: { selectedFontStyle = style }) {
                                    Text("Aa")
                                        .font(style.font)
                                        .foregroundColor(selectedFontStyle == style ? .white : .primary)
                                        .frame(width: 60, height: 60)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedFontStyle == style ? AppTheme.Colors.primary : Color(.systemGray5))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Text color selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Text Color")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? .white : .clear, lineWidth: 3)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Background gradient selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Background")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(gradients.indices, id: \.self) { index in
                                Button(action: { backgroundGradient = gradients[index] }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: gradients[index],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 40)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(backgroundGradient == gradients[index] ? .white : .clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let textOverlay = CreateStoryViewModel.TextOverlay(
                            text: text,
                            color: selectedColor,
                            backgroundColor: selectedBackgroundColor,
                            fontStyle: selectedFontStyle
                        )
                        onTextCreated(textOverlay)
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    TextEditorSheet { textOverlay in
        print("Text created: \(textOverlay.text)")
    }
}