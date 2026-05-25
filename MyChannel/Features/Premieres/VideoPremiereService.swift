//
//  VideoPremiereService.swift
//  MyChannel
//
//  Created by AI Assistant on 10/19/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Video Premiere Service (YouTube Parity)
@MainActor
class VideoPremiereService: ObservableObject {
    static let shared = VideoPremiereService()
    
    @Published var scheduledPremieres: [VideoPremiere] = []
    @Published var livePremieres: [VideoPremiere] = []
    @Published var isScheduling = false
    @Published var premiereChat: [PremiereMessage] = []
    
    private let networkService = NetworkService.shared
    private let notificationService = PushNotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPremiereMonitoring()
    }
    
    // MARK: - Premiere Scheduling
    
    /// Schedule a video premiere (YouTube parity feature)
    func scheduleVideoPremiere(
        videoId: String,
        premiereDate: Date,
        title: String,
        description: String,
        thumbnailURL: String,
        enableChat: Bool = true,
        enableCountdown: Bool = true
    ) async throws -> VideoPremiere {
        
        isScheduling = true
        defer { isScheduling = false }
        
        let premiere = VideoPremiere(
            id: UUID().uuidString,
            videoId: videoId,
            title: title,
            description: description,
            thumbnailURL: thumbnailURL,
            scheduledDate: premiereDate,
            status: .scheduled,
            enableChat: enableChat,
            enableCountdown: enableCountdown,
            createdAt: Date()
        )
        
        // Save premiere to backend
        try await networkService.post(
            endpoint: .custom("/premieres"),
            body: premiere,
            responseType: VideoPremiere.self
        )
        
        // Schedule notifications
        await schedulePremiereNotifications(premiere: premiere)
        
        // Add to local state
        scheduledPremieres.append(premiere)
        
        return premiere
    }
    
    /// Start a scheduled premiere
    func startPremiere(_ premiereId: String) async throws {
        guard let index = scheduledPremieres.firstIndex(where: { $0.id == premiereId }) else {
            throw PremiereError.premiereNotFound
        }
        
        var premiere = scheduledPremieres[index]
        premiere.status = .live
        premiere.actualStartTime = Date()
        
        // Update backend
        try await networkService.put(
            endpoint: .custom("/premieres/\(premiereId)"),
            body: premiere,
            responseType: VideoPremiere.self
        )
        
        // Move to live premieres
        scheduledPremieres.remove(at: index)
        livePremieres.append(premiere)
        
        // Send live notifications to subscribers
        await notifySubscribersPremiereStarted(premiere: premiere)
        
        // Initialize premiere chat
        if premiere.enableChat {
            await initializePremiereChat(premiereId: premiereId)
        }
    }
    
    /// End a live premiere
    func endPremiere(_ premiereId: String) async throws {
        guard let index = livePremieres.firstIndex(where: { $0.id == premiereId }) else {
            throw PremiereError.premiereNotFound
        }
        
        var premiere = livePremieres[index]
        premiere.status = .ended
        premiere.endTime = Date()
        
        // Update backend
        try await networkService.put(
            endpoint: .custom("/premieres/\(premiereId)"),
            body: premiere,
            responseType: VideoPremiere.self
        )
        
        // Remove from live premieres
        livePremieres.remove(at: index)
        
        // Archive premiere chat
        await archivePremiereChat(premiereId: premiereId)
    }
    
    // MARK: - Premiere Chat
    
    /// Send message in premiere chat
    func sendPremiereMessage(
        premiereId: String,
        userId: String,
        message: String
    ) async throws {
        let chatMessage = PremiereMessage(
            id: UUID().uuidString,
            premiereId: premiereId,
            userId: userId,
            message: message,
            timestamp: Date(),
            messageType: .regular
        )
        
        // Send to backend
        try await networkService.post(
            endpoint: .custom("/premieres/\(premiereId)/chat"),
            body: chatMessage,
            responseType: PremiereMessage.self
        )
        
        // Add to local chat
        premiereChat.append(chatMessage)
    }
    
    /// Get premiere waiting room info
    func getPremiereWaitingRoom(_ premiereId: String) async throws -> PremiereWaitingRoom {
        return try await networkService.get(
            endpoint: .custom("/premieres/\(premiereId)/waiting-room"),
            responseType: PremiereWaitingRoom.self
        )
    }
    
    // MARK: - Private Methods
    
    private func setupPremiereMonitoring() {
        // Monitor for premieres that should start
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkScheduledPremieres()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkScheduledPremieres() async {
        let now = Date()
        
        for premiere in scheduledPremieres {
            if premiere.scheduledDate <= now && premiere.status == .scheduled {
                try? await startPremiere(premiere.id)
            }
        }
    }
    
    private func schedulePremiereNotifications(premiere: VideoPremiere) async {
        // Schedule notifications at different intervals
        let notificationTimes = [
            Calendar.current.date(byAdding: .hour, value: -24, to: premiere.scheduledDate),
            Calendar.current.date(byAdding: .hour, value: -1, to: premiere.scheduledDate),
            Calendar.current.date(byAdding: .minute, value: -15, to: premiere.scheduledDate)
        ].compactMap { $0 }
        
        for notificationTime in notificationTimes {
            await notificationService.schedulePremiereReminder(
                premiere: premiere,
                scheduledFor: notificationTime
            )
        }
    }
    
    private func notifySubscribersPremiereStarted(premiere: VideoPremiere) async {
        // Send push notifications to all subscribers
        await notificationService.sendPremiereStartedNotification(premiere: premiere)
    }
    
    private func initializePremiereChat(premiereId: String) async {
        // Initialize real-time chat for premiere
        premiereChat.removeAll()
        
        // Add welcome message
        let welcomeMessage = PremiereMessage(
            id: UUID().uuidString,
            premiereId: premiereId,
            userId: "system",
            message: "Welcome to the premiere! Chat with other viewers while you wait.",
            timestamp: Date(),
            messageType: .system
        )
        
        premiereChat.append(welcomeMessage)
    }
    
    private func archivePremiereChat(premiereId: String) async {
        // Archive chat messages for later viewing
        try? await networkService.post(
            endpoint: .custom("/premieres/\(premiereId)/archive-chat"),
            body: ["messages": premiereChat],
            responseType: EmptyResponse.self
        )
        
        premiereChat.removeAll()
    }
}

// MARK: - Models

struct VideoPremiere: Identifiable, Codable {
    let id: String
    let videoId: String
    let title: String
    let description: String
    let thumbnailURL: String
    let scheduledDate: Date
    var status: PremiereStatus
    let enableChat: Bool
    let enableCountdown: Bool
    let createdAt: Date
    var actualStartTime: Date?
    var endTime: Date?
    var viewerCount: Int = 0
    var chatMessageCount: Int = 0
}

enum PremiereStatus: String, Codable {
    case scheduled = "scheduled"
    case live = "live"
    case ended = "ended"
    case cancelled = "cancelled"
}

struct PremiereMessage: Identifiable, Codable {
    let id: String
    let premiereId: String
    let userId: String
    let message: String
    let timestamp: Date
    let messageType: PremiereMessageType
}

enum PremiereMessageType: String, Codable {
    case regular = "regular"
    case system = "system"
    case moderator = "moderator"
    case creator = "creator"
}

struct PremiereWaitingRoom: Codable {
    let premiereId: String
    let waitingViewers: Int
    let timeUntilStart: TimeInterval
    let isLive: Bool
    let chatEnabled: Bool
    let countdownEnabled: Bool
}

enum PremiereError: Error {
    case premiereNotFound
    case invalidScheduleTime
    case chatDisabled
    case premiereAlreadyStarted
    case premiereEnded
}

// MARK: - Extensions

extension PushNotificationService {
    func schedulePremiereReminder(premiere: VideoPremiere, scheduledFor: Date) async {
        // Implementation for scheduling premiere reminders
    }
    
    func sendPremiereStartedNotification(premiere: VideoPremiere) async {
        // Implementation for sending premiere started notifications
    }
}

