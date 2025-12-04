//
//  InfoCardOverlayView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Info Card Overlay View (Shows during video playback)
struct InfoCardOverlayView: View {
    let card: InfoCard
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var showExpanded = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                if showExpanded {
                    expandedCardView
                } else {
                    teaserView
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 80) // Above player controls
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - Teaser View (Small "i" icon)
    private var teaserView: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showExpanded = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text(card.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
    }
    
    // MARK: - Expanded Card View
    private var expandedCardView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button
            HStack {
                Image(systemName: card.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(card.type.color)
                
                Text(card.type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showExpanded = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Thumbnail (if available)
            if let thumbnailURL = card.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: card.iconName)
                                .font(.title)
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
                .frame(height: 100)
                .clipped()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let message = card.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                // CTA Button
                Button {
                    onTap()
                } label: {
                    HStack {
                        Text(card.callToAction)
                            .font(.system(size: 13, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(card.type.color)
                    .cornerRadius(20)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
    }
}

// MARK: - Info Cards Container (Manages multiple cards)
struct InfoCardsContainerView: View {
    @ObservedObject var manager: InfoCardPlaybackManager
    let onCardTap: (InfoCard) -> Void
    
    var body: some View {
        ZStack {
            // Show teaser indicator
            if manager.showCardTeaser, let teaserCard = manager.currentTeaserCard {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        cardTeaserIndicator(for: teaserCard)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 120)
                }
            }
            
            // Show visible cards
            ForEach(manager.visibleCards) { card in
                InfoCardOverlayView(
                    card: card,
                    onTap: { onCardTap(card) },
                    onDismiss: { manager.dismissCard(card.id) }
                )
            }
        }
    }
    
    private func cardTeaserIndicator(for card: InfoCard) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(card.type.color)
                .frame(width: 8, height: 8)
            
            Text("Card coming up")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.6))
        )
        .transition(.opacity)
    }
}

#Preview("Info Card Overlay") {
    ZStack {
        // Simulated video background
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.black, .gray.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        
        InfoCardOverlayView(
            card: InfoCard.sampleCards[0],
            onTap: { print("Card tapped") },
            onDismiss: { print("Card dismissed") }
        )
    }
    .ignoresSafeArea()
}

#Preview("Multiple Card Types") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(InfoCard.sampleCards) { card in
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: card.iconName)
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(card.type.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.headline)
                            
                            if let message = card.message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("@ \(card.formattedTimestamp)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text(card.callToAction)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(card.type.color)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}



