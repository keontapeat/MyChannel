//
//  EditableElementView.swift
//  MyChannel
//
//  ✍️ EDITABLE ELEMENT VIEW
//  Draggable, scalable, rotatable story elements
//

import SwiftUI

struct EditableElementView: View {
    let element: EditableElement
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: (CGSize) -> Void
    let onScale: (CGFloat) -> Void
    let onRotate: (Angle) -> Void
    
    @State private var currentOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0
    @State private var lastRotation: Angle = .zero
    @State private var currentRotation: Angle = .zero
    
    var body: some View {
        GeometryReader { geometry in
            elementContent
                .position(
                    x: element.position.x * geometry.size.width,
                    y: element.position.y * geometry.size.height
                )
                .scaleEffect(element.scale * currentScale)
                .rotationEffect(Angle(degrees: element.rotation) + currentRotation)
                .gesture(dragGesture)
                .gesture(magnificationGesture)
                .gesture(rotationGesture)
                .onTapGesture {
                    onTap()
                }
        }
    }
    
    @ViewBuilder
    private var elementContent: some View {
        Group {
            switch element.type {
            case .text(let text):
                textElement(text)
            case .sticker(let sticker):
                stickerElement(sticker)
            case .drawing:
                EmptyView() // Drawing handled separately
            }
        }
        .overlay(
            Group {
                if isSelected {
                    selectionBorder
                }
            }
        )
    }
    
    private func textElement(_ text: String) -> some View {
        Text(text)
            .font(element.font?.systemFont ?? .system(size: 32, weight: .bold))
            .foregroundColor(element.color ?? .white)
            .padding(12)
            .background(
                backgroundForStyle(element.backgroundStyle ?? .none)
            )
            .multilineTextAlignment(.center)
    }
    
    private func stickerElement(_ sticker: Sticker) -> some View {
        // TODO: Load sticker image
        Image(systemName: "star.fill")
            .font(.system(size: 60))
            .foregroundColor(.yellow)
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
    
    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                style: StrokeStyle(
                    lineWidth: 2,
                    dash: [5, 3]
                )
            )
            .foregroundColor(.white)
            .padding(-8)
    }
    
    // MARK: - Gestures
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentOffset = value.translation
            }
            .onEnded { value in
                onDrag(value.translation)
                currentOffset = .zero
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = value / lastScale
            }
            .onEnded { value in
                let newScale = element.scale * value
                onScale(newScale)
                lastScale = value
                currentScale = 1.0
            }
    }
    
    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                currentRotation = value - lastRotation
            }
            .onEnded { value in
                let newRotation = Angle(degrees: element.rotation) + value
                onRotate(newRotation)
                lastRotation = value
                currentRotation = .zero
            }
    }
}


