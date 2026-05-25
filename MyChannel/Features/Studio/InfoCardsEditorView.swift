//
//  InfoCardsEditorView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Info Cards Editor View
struct InfoCardsEditorView: View {
    let videoId: String
    let videoDuration: TimeInterval
    
    @StateObject private var service = InfoCardService.shared
    @State private var cards: [InfoCard] = []
    @State private var showAddCard = false
    @State private var editingCard: InfoCard?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading cards...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.lg) {
                            // Header Info
                            infoHeader
                            
                            // Timeline View
                            timelineView
                            
                            // Cards List
                            cardsListView
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Info Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCard = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .disabled(cards.count >= 5)
                }
            }
            .sheet(isPresented: $showAddCard) {
                InfoCardEditorSheet(
                    videoId: videoId,
                    videoDuration: videoDuration,
                    existingCard: nil
                ) { newCard in
                    Task {
                        try? await service.createCard(newCard)
                        await loadCards()
                    }
                }
            }
            .sheet(item: $editingCard) { card in
                InfoCardEditorSheet(
                    videoId: videoId,
                    videoDuration: videoDuration,
                    existingCard: card
                ) { updatedCard in
                    Task {
                        try? await service.updateCard(updatedCard)
                        await loadCards()
                    }
                }
            }
            .task {
                await loadCards()
            }
        }
    }
    
    // MARK: - Info Header
    private var infoHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppTheme.Colors.accent)
                
                Text("About Info Cards")
                    .font(AppTheme.Typography.headline)
            }
            
            Text("Info cards appear during video playback to promote your content, link to external sites, and engage viewers. You can add up to 5 cards per video.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Timeline View
    private var timelineView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Timeline")
                .font(AppTheme.Typography.headline)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Timeline track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.surface)
                        .frame(height: 40)
                    
                    // Card markers
                    ForEach(cards) { card in
                        let position = CGFloat(card.timestamp / videoDuration) * geometry.size.width
                        
                        VStack(spacing: 2) {
                            Image(systemName: card.iconName)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(card.type.color)
                                .clipShape(Circle())
                            
                            Rectangle()
                                .fill(card.type.color)
                                .frame(width: 2, height: 12)
                        }
                        .position(x: position, y: 20)
                    }
                }
            }
            .frame(height: 50)
            
            // Time labels
            HStack {
                Text("0:00")
                Spacer()
                Text(formatDuration(videoDuration / 2))
                Spacer()
                Text(formatDuration(videoDuration))
            }
            .font(AppTheme.Typography.caption2)
            .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Cards List View
    private var cardsListView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Cards (\(cards.count)/5)")
                    .font(AppTheme.Typography.headline)
                
                Spacer()
                
                if !cards.isEmpty {
                    Button("Reorder") {
                        // Reorder functionality
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if cards.isEmpty {
                emptyStateView
            } else {
                ForEach(cards) { card in
                    InfoCardRowView(card: card) {
                        editingCard = card
                    } onDelete: {
                        Task {
                            try? await service.deleteCard(id: card.id)
                            await loadCards()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No cards yet")
                .font(AppTheme.Typography.headline)
            
            Text("Add info cards to promote content and engage viewers during your video.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                showAddCard = true
            } label: {
                Label("Add Card", systemImage: "plus")
                    .font(AppTheme.Typography.bodyMedium)
            }
            .modernButtonStyle()
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
    
    // MARK: - Helper Methods
    private func loadCards() async {
        isLoading = true
        do {
            cards = try await service.getCards(for: videoId)
        } catch {
            print("Failed to load cards: \(error)")
        }
        isLoading = false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Info Card Row View
struct InfoCardRowView: View {
    let card: InfoCard
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Icon
            Image(systemName: card.iconName)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(card.type.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(1)
                
                if let message = card.message {
                    Text(message)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: AppTheme.Spacing.sm) {
                    Label(card.formattedTimestamp, systemImage: "clock")
                    
                    Text("•")
                    
                    Text(card.type.displayName)
                }
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
            
            // Actions
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This card will be permanently removed from your video.")
        }
    }
}

// MARK: - Info Card Editor Sheet
struct InfoCardEditorSheet: View {
    let videoId: String
    let videoDuration: TimeInterval
    let existingCard: InfoCard?
    let onSave: (InfoCard) -> Void
    
    @State private var cardType: InfoCardType = .video
    @State private var title = ""
    @State private var message = ""
    @State private var timestamp: TimeInterval = 0
    @State private var destinationURL = ""
    @State private var destinationId = ""
    @State private var customCTA = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var isEditing: Bool { existingCard != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // Card Type
                Section("Card Type") {
                    Picker("Type", selection: $cardType) {
                        ForEach(InfoCardType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Card Content
                Section("Content") {
                    TextField("Title", text: $title)
                    TextField("Message (optional)", text: $message)
                    TextField("Custom Button Text (optional)", text: $customCTA)
                        .textInputAutocapitalization(.words)
                }
                
                // Timing
                Section("Timing") {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Show at:")
                            Spacer()
                            Text(formatDuration(timestamp))
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Slider(value: $timestamp, in: 0...videoDuration, step: 1)
                            .tint(AppTheme.Colors.primary)
                    }
                    
                    Text("Card will appear for 5 seconds starting at this time")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                // Destination
                Section("Destination") {
                    switch cardType {
                    case .video, .playlist, .channel:
                        TextField("\(cardType.displayName) ID", text: $destinationId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                    case .link, .merchandise, .donation, .associatedWebsite:
                        TextField("URL", text: $destinationURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        
                    case .poll:
                        TextField("Poll ID", text: $destinationId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                
                // Preview
                Section("Preview") {
                    previewCard
                }
            }
            .navigationTitle(isEditing ? "Edit Card" : "Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let card = existingCard {
                    cardType = card.type
                    title = card.title
                    message = card.message ?? ""
                    timestamp = card.timestamp
                    customCTA = card.customCallToAction ?? ""
                    
                    // Extract destination
                    switch card.destination {
                    case .videoId(let id), .playlistId(let id), .channelId(let id), .pollId(let id):
                        destinationId = id
                    case .externalURL(let url), .merchandiseURL(let url), .donationURL(let url):
                        destinationURL = url
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Card
    private var previewCard: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: cardType.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(cardType.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "Card Title" : title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(title.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                
                if !message.isEmpty {
                    Text(message)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text(customCTA.isEmpty ? cardType.defaultCallToAction : customCTA)
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(cardType.color)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func saveCard() {
        let destination: InfoCardDestination
        switch cardType {
        case .video:
            destination = .videoId(destinationId)
        case .playlist:
            destination = .playlistId(destinationId)
        case .channel:
            destination = .channelId(destinationId)
        case .link, .associatedWebsite:
            destination = .externalURL(destinationURL)
        case .poll:
            destination = .pollId(destinationId)
        case .merchandise:
            destination = .merchandiseURL(destinationURL)
        case .donation:
            destination = .donationURL(destinationURL)
        }
        
        let card = InfoCard(
            id: existingCard?.id ?? UUID().uuidString,
            videoId: videoId,
            type: cardType,
            title: title,
            message: message.isEmpty ? nil : message,
            timestamp: timestamp,
            destination: destination,
            customCallToAction: customCTA.isEmpty ? nil : customCTA,
            createdAt: existingCard?.createdAt ?? Date()
        )
        
        onSave(card)
        dismiss()
    }
}

#Preview {
    InfoCardsEditorView(videoId: "video-1", videoDuration: 600)
}







