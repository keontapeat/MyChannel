//
//  InfoCardService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI
import Combine

// MARK: - Info Card Service Protocol
protocol InfoCardServiceProtocol {
    func getCards(for videoId: String) async throws -> [InfoCard]
    func createCard(_ card: InfoCard) async throws -> InfoCard
    func updateCard(_ card: InfoCard) async throws -> InfoCard
    func deleteCard(id: String) async throws
    func reorderCards(videoId: String, cardIds: [String]) async throws
}

// MARK: - Info Card Service
@MainActor
class InfoCardService: ObservableObject, InfoCardServiceProtocol {
    static let shared = InfoCardService()
    
    @Published var cards: [String: [InfoCard]] = [:] // videoId -> cards
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {
        // Load sample data
        loadSampleData()
    }
    
    private func loadSampleData() {
        // Group sample cards by videoId
        for card in InfoCard.sampleCards {
            if cards[card.videoId] == nil {
                cards[card.videoId] = []
            }
            cards[card.videoId]?.append(card)
        }
    }
    
    // MARK: - Public Methods
    func getCards(for videoId: String) async throws -> [InfoCard] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return cards[videoId]?.sorted(by: { $0.timestamp < $1.timestamp }) ?? []
    }
    
    func createCard(_ card: InfoCard) async throws -> InfoCard {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        if cards[card.videoId] == nil {
            cards[card.videoId] = []
        }
        cards[card.videoId]?.append(card)
        
        return card
    }
    
    func updateCard(_ card: InfoCard) async throws -> InfoCard {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard var videoCards = cards[card.videoId],
              let index = videoCards.firstIndex(where: { $0.id == card.id }) else {
            throw InfoCardError.cardNotFound
        }
        
        videoCards[index] = card
        cards[card.videoId] = videoCards
        
        return card
    }
    
    func deleteCard(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        for (videoId, videoCards) in cards {
            if videoCards.contains(where: { $0.id == id }) {
                cards[videoId] = videoCards.filter { $0.id != id }
                return
            }
        }
        
        throw InfoCardError.cardNotFound
    }
    
    func reorderCards(videoId: String, cardIds: [String]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        guard var videoCards = cards[videoId] else {
            throw InfoCardError.videoNotFound
        }
        
        var reorderedCards: [InfoCard] = []
        for cardId in cardIds {
            if let card = videoCards.first(where: { $0.id == cardId }) {
                reorderedCards.append(card)
            }
        }
        
        cards[videoId] = reorderedCards
    }
    
    // MARK: - Helper Methods
    func getCardsAtTimestamp(_ timestamp: TimeInterval, for videoId: String) -> [InfoCard] {
        guard let videoCards = cards[videoId] else { return [] }
        
        return videoCards.filter { card in
            timestamp >= card.timestamp && timestamp <= card.timestamp + card.duration
        }
    }
    
    func getUpcomingCard(after timestamp: TimeInterval, for videoId: String) -> InfoCard? {
        guard let videoCards = cards[videoId] else { return nil }
        
        return videoCards
            .filter { $0.timestamp > timestamp }
            .sorted(by: { $0.timestamp < $1.timestamp })
            .first
    }
}

// MARK: - Info Card Error
enum InfoCardError: LocalizedError {
    case cardNotFound
    case videoNotFound
    case invalidDestination
    case maxCardsReached
    
    var errorDescription: String? {
        switch self {
        case .cardNotFound: return "Card not found"
        case .videoNotFound: return "Video not found"
        case .invalidDestination: return "Invalid card destination"
        case .maxCardsReached: return "Maximum number of cards reached (5 per video)"
        }
    }
}

// MARK: - Info Card Manager (for playback)
@MainActor
class InfoCardPlaybackManager: ObservableObject {
    @Published var visibleCards: [InfoCard] = []
    @Published var dismissedCardIds: Set<String> = []
    @Published var showCardTeaser = false
    @Published var currentTeaserCard: InfoCard?
    
    private let service: InfoCardService
    private var allCards: [InfoCard] = []
    private var currentVideoId: String?
    
    init(service: InfoCardService = .shared) {
        self.service = service
    }
    
    func loadCards(for videoId: String) async {
        currentVideoId = videoId
        dismissedCardIds.removeAll()
        visibleCards.removeAll()
        
        do {
            allCards = try await service.getCards(for: videoId)
        } catch {
            print("Failed to load cards: \(error)")
            allCards = []
        }
    }
    
    func updatePlaybackTime(_ time: TimeInterval) {
        // Find cards that should be visible at this time
        let cardsAtTime = allCards.filter { card in
            !dismissedCardIds.contains(card.id) &&
            time >= card.timestamp &&
            time <= card.timestamp + card.duration
        }
        
        // Update visible cards
        visibleCards = cardsAtTime
        
        // Show teaser for upcoming cards
        if let nextCard = allCards.first(where: { card in
            !dismissedCardIds.contains(card.id) &&
            card.timestamp > time &&
            card.timestamp - time <= 2.0 // Show teaser 2 seconds before
        }) {
            currentTeaserCard = nextCard
            showCardTeaser = true
        } else {
            showCardTeaser = false
            currentTeaserCard = nil
        }
    }
    
    func dismissCard(_ cardId: String) {
        dismissedCardIds.insert(cardId)
        visibleCards.removeAll { $0.id == cardId }
    }
    
    func resetDismissedCards() {
        dismissedCardIds.removeAll()
    }
}
