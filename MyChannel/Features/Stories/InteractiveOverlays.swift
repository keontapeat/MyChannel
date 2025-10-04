//
//  InteractiveOverlays.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Interactive Sticker View
struct InteractiveStickerView: View {
    let sticker: CreateStoryViewModel.StickerItem
    let onUpdate: (CreateStoryViewModel.StickerItem) -> Void
    let onRemove: () -> Void
    
    @State private var currentPosition: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var currentRotation: Double = 0.0
    @State private var isSelected = false
    @State private var lastScale: CGFloat = 1.0
    @State private var lastRotation: Double = 0.0
    
    var body: some View {
        ZStack {
            // Sticker content
            Group {
                switch sticker.type {
                case .emoji:
                    if let emoji = sticker.data as? String {
                        Text(emoji)
                            .font(.system(size: 60))
                    }
                    
                case .location:
                    if let location = sticker.data as? String {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                            Text(location)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.7))
                        .cornerRadius(16)
                    }
                    
                case .mention:
                    if let username = sticker.data as? String {
                        Text("@\(username)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(16)
                    }
                    
                case .hashtag:
                    if let hashtag = sticker.data as? String {
                        Text("#\(hashtag)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue)
                            .cornerRadius(16)
                    }
                    
                case .time:
                    VStack(spacing: 4) {
                        Text(Date().formatted(date: .omitted, time: .shortened))
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(.black.opacity(0.7))
                    .cornerRadius(12)
                    
                default:
                    Text("Sticker")
                        .foregroundColor(.white)
                }
            }
            
            // Selection indicator
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.Colors.primary, lineWidth: 2)
                    .background(.clear)
                    .scaleEffect(1.1)
                
                // Delete button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
                .offset(x: 20, y: -20)
            }
        }
        .scaleEffect(currentScale * sticker.scale)
        .rotationEffect(.degrees(currentRotation + sticker.rotation))
        .offset(currentPosition)
        .position(
            x: sticker.position.x * UIScreen.main.bounds.width,
            y: sticker.position.y * UIScreen.main.bounds.height
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isSelected.toggle()
            }
        }
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        currentPosition = value.translation
                    }
                    .onEnded { value in
                        var updatedSticker = sticker
                        let newX = (sticker.position.x * UIScreen.main.bounds.width + value.translation.width) / UIScreen.main.bounds.width
                        let newY = (sticker.position.y * UIScreen.main.bounds.height + value.translation.height) / UIScreen.main.bounds.height
                        updatedSticker.position = CGPoint(
                            x: max(0, min(1, newX)),
                            y: max(0, min(1, newY))
                        )
                        onUpdate(updatedSticker)
                        currentPosition = .zero
                    },
                
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = lastScale * value
                        }
                        .onEnded { value in
                            lastScale = currentScale
                            var updatedSticker = sticker
                            updatedSticker.scale = max(0.5, min(3.0, lastScale))
                            onUpdate(updatedSticker)
                        },
                    
                    RotationGesture()
                        .onChanged { value in
                            currentRotation = lastRotation + value.degrees
                        }
                        .onEnded { value in
                            lastRotation = currentRotation
                            var updatedSticker = sticker
                            updatedSticker.rotation = currentRotation
                            onUpdate(updatedSticker)
                        }
                )
            )
        )
    }
}

// MARK: - Interactive Text Overlay
struct InteractiveTextOverlay: View {
    let textOverlay: CreateStoryViewModel.TextOverlay
    let onUpdate: (CreateStoryViewModel.TextOverlay) -> Void
    let onRemove: () -> Void
    
    @State private var currentPosition: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var currentRotation: Double = 0.0
    @State private var isSelected = false
    @State private var lastScale: CGFloat = 1.0
    @State private var lastRotation: Double = 0.0
    
    var body: some View {
        ZStack {
            // Text content
            Text(textOverlay.text)
                .font(textOverlay.fontStyle.font)
                .foregroundColor(textOverlay.color)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    textOverlay.backgroundColor == .clear ? nil : textOverlay.backgroundColor.opacity(0.8)
                )
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Selection indicator
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.Colors.primary, lineWidth: 2)
                    .background(.clear)
                    .scaleEffect(1.1)
                
                // Delete button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
                .offset(x: 20, y: -20)
            }
        }
        .scaleEffect(currentScale * textOverlay.scale)
        .rotationEffect(.degrees(currentRotation + textOverlay.rotation))
        .offset(currentPosition)
        .position(
            x: textOverlay.position.x * UIScreen.main.bounds.width,
            y: textOverlay.position.y * UIScreen.main.bounds.height
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isSelected.toggle()
            }
        }
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        currentPosition = value.translation
                    }
                    .onEnded { value in
                        var updatedOverlay = textOverlay
                        let newX = (textOverlay.position.x * UIScreen.main.bounds.width + value.translation.width) / UIScreen.main.bounds.width
                        let newY = (textOverlay.position.y * UIScreen.main.bounds.height + value.translation.height) / UIScreen.main.bounds.height
                        updatedOverlay.position = CGPoint(
                            x: max(0, min(1, newX)),
                            y: max(0, min(1, newY))
                        )
                        onUpdate(updatedOverlay)
                        currentPosition = .zero
                    },
                
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = lastScale * value
                        }
                        .onEnded { value in
                            lastScale = currentScale
                            var updatedOverlay = textOverlay
                            updatedOverlay.scale = max(0.5, min(3.0, lastScale))
                            onUpdate(updatedOverlay)
                        },
                    
                    RotationGesture()
                        .onChanged { value in
                            currentRotation = lastRotation + value.degrees
                        }
                        .onEnded { value in
                            lastRotation = currentRotation
                            var updatedOverlay = textOverlay
                            updatedOverlay.rotation = currentRotation
                            onUpdate(updatedOverlay)
                        }
                )
            )
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        InteractiveStickerView(
            sticker: CreateStoryViewModel.StickerItem(
                type: .emoji,
                data: "😀"
            ),
            onUpdate: { _ in },
            onRemove: { }
        )
        
        InteractiveTextOverlay(
            textOverlay: CreateStoryViewModel.TextOverlay(
                text: "Hello World!"
            ),
            onUpdate: { _ in },
            onRemove: { }
        )
    }
}