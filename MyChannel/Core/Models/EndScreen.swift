//
//  EndScreen.swift
//  MyChannel
//
//  Advanced End Screens & Cards for YouTube Parity
//

import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - End Screen Models

struct EndScreen: Identifiable, Codable {
    let id: String
    let videoId: String
    let elements: [EndScreenElement]
    let duration: TimeInterval // How long end screen shows
    let startTime: TimeInterval // When to show (seconds before video ends)
    
    init(videoId: String, elements: [EndScreenElement] = [], duration: TimeInterval = 20, startTime: TimeInterval = 20) {
        self.id = UUID().uuidString
        self.videoId = videoId
        self.elements = elements
        self.duration = duration
        self.startTime = startTime
    }
}

struct EndScreenElement: Identifiable, Codable {
    let id: String
    let type: EndScreenElementType
    let position: CGRect // Normalized coordinates (0-1)
    let content: EndScreenContent
    let animation: EndScreenAnimation
    let isEnabled: Bool
    
    init(type: EndScreenElementType, position: CGRect, content: EndScreenContent, animation: EndScreenAnimation = .fadeIn, isEnabled: Bool = true) {
        self.id = UUID().uuidString
        self.type = type
        self.position = position
        self.content = content
        self.animation = animation
        self.isEnabled = isEnabled
    }
}

enum EndScreenElementType: String, Codable, CaseIterable {
    case video = "video"
    case playlist = "playlist"
    case subscribe = "subscribe"
    case channel = "channel"
    case link = "link"
    case bestForViewer = "best_for_viewer"
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .playlist: return "Playlist"
        case .subscribe: return "Subscribe"
        case .channel: return "Channel"
        case .link: return "Website"
        case .bestForViewer: return "Best for Viewer"
        }
    }
    
    var icon: String {
        switch self {
        case .video: return "play.rectangle"
        case .playlist: return "list.bullet.rectangle"
        case .subscribe: return "bell.badge.fill"
        case .channel: return "person.crop.circle"
        case .link: return "link"
        case .bestForViewer: return "sparkles"
        }
    }
}

struct EndScreenContent: Codable {
    let title: String?
    let subtitle: String?
    let thumbnailURL: String?
    let targetVideoId: String?
    let targetPlaylistId: String?
    let targetChannelId: String?
    let externalURL: String?
    let customText: String?
}

enum EndScreenAnimation: String, Codable, CaseIterable {
    case fadeIn = "fade_in"
    case slideUp = "slide_up"
    case slideDown = "slide_down"
    case slideLeft = "slide_left"
    case slideRight = "slide_right"
    case scaleUp = "scale_up"
    case bounce = "bounce"
    
    var displayName: String {
        switch self {
        case .fadeIn: return "Fade In"
        case .slideUp: return "Slide Up"
        case .slideDown: return "Slide Down"
        case .slideLeft: return "Slide Left"
        case .slideRight: return "Slide Right"
        case .scaleUp: return "Scale Up"
        case .bounce: return "Bounce"
        }
    }
}

// MARK: - Cards Models
// Note: VideoCard is defined in Video.swift to avoid duplication

enum EndScreenCardType: String, Codable, CaseIterable {
    case video = "video"
    case playlist = "playlist"
    case channel = "channel"
    case link = "link"
    case poll = "poll"
    case donation = "donation"
    
    var displayName: String {
        switch self {
        case .video: return "Video or Playlist"
        case .playlist: return "Playlist"
        case .channel: return "Channel"
        case .link: return "Link"
        case .poll: return "Poll"
        case .donation: return "Donation"
        }
    }
    
    var icon: String {
        switch self {
        case .video: return "play.rectangle"
        case .playlist: return "list.bullet.rectangle"
        case .channel: return "person.crop.circle"
        case .link: return "link"
        case .poll: return "chart.bar.doc.horizontal"
        case .donation: return "heart.circle"
        }
    }
}

enum CardPosition: String, Codable, CaseIterable {
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
    
    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

// MARK: - Service

@MainActor
class EndScreenService: ObservableObject {
    static let shared = EndScreenService()
    
    @Published var endScreens: [String: EndScreen] = [:]
    @Published var cards: [String: [VideoCard]] = [:]
    
    private init() {}
    
    // MARK: - End Screens
    
    func saveEndScreen(_ endScreen: EndScreen) async {
        endScreens[endScreen.videoId] = endScreen
        
        // Save to Firestore
        #if canImport(FirebaseFirestore)
        do {
            let db = FirebaseFirestore.Firestore.firestore()
            let data = try JSONEncoder().encode(endScreen)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            try await db.collection("endScreens").document(endScreen.videoId).setData(dict)
        } catch {
            print("Error saving end screen: \(error)")
        }
        #endif
    }
    
    func getEndScreen(for videoId: String) -> EndScreen? {
        return endScreens[videoId]
    }
    
    func deleteEndScreen(for videoId: String) async {
        endScreens.removeValue(forKey: videoId)
        
        #if canImport(FirebaseFirestore)
        do {
            let db = FirebaseFirestore.Firestore.firestore()
            try await db.collection("endScreens").document(videoId).delete()
        } catch {
            print("Error deleting end screen: \(error)")
        }
        #endif
    }
    
    // MARK: - Cards
    
    func saveCard(_ card: VideoCard, for videoId: String) async {
        if cards[videoId] == nil {
            cards[videoId] = []
        }
        
        // Remove existing card with same ID
        cards[videoId]?.removeAll { $0.id == card.id }
        cards[videoId]?.append(card)
        
        // Save to Firestore
        #if canImport(FirebaseFirestore)
        do {
            let db = FirebaseFirestore.Firestore.firestore()
            let data = try JSONEncoder().encode(card)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            try await db.collection("cards").document(card.id).setData(dict)
        } catch {
            print("Error saving card: \(error)")
        }
        #endif
    }
    
    func getCards(for videoId: String) -> [VideoCard] {
        return cards[videoId] ?? []
    }
    
    func deleteCard(_ cardId: String, from videoId: String) async {
        cards[videoId]?.removeAll { $0.id == cardId }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = FirebaseFirestore.Firestore.firestore()
            try await db.collection("cards").document(cardId).delete()
        } catch {
            print("Error deleting card: \(error)")
        }
        #endif
    }
    
    // MARK: - Templates
    
    func createDefaultEndScreen(for videoId: String) -> EndScreen {
        let subscribeElement = EndScreenElement(
            type: .subscribe,
            position: CGRect(x: 0.05, y: 0.7, width: 0.4, height: 0.25),
            content: EndScreenContent(
                title: "Subscribe",
                subtitle: "for more content",
                thumbnailURL: nil,
                targetVideoId: nil,
                targetPlaylistId: nil,
                targetChannelId: nil,
                externalURL: nil,
                customText: nil
            )
        )
        
        let bestForViewerElement = EndScreenElement(
            type: .bestForViewer,
            position: CGRect(x: 0.55, y: 0.7, width: 0.4, height: 0.25),
            content: EndScreenContent(
                title: "Watch Next",
                subtitle: "Recommended for you",
                thumbnailURL: nil,
                targetVideoId: nil,
                targetPlaylistId: nil,
                targetChannelId: nil,
                externalURL: nil,
                customText: nil
            )
        )
        
        return EndScreen(
            videoId: videoId,
            elements: [subscribeElement, bestForViewerElement]
        )
    }
}
