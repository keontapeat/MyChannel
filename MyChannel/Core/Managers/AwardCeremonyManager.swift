//
//  AwardCeremonyManager.swift
//  MyChannel
//
//  Manages award ceremony livestream state and winner announcements
//

import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Award Winner Model

struct AwardWinner: Identifiable, Codable {
    let id: String
    let categoryId: String
    let categoryName: String
    let winnerId: String
    let winnerName: String
    let profileImageURL: String?
    let prizeAmount: String
    let voteCount: Int
    let announcedAt: Date
}

// MARK: - Ceremony Host Model

struct CeremonyHost: Identifiable, Codable {
    let id: String
    let displayName: String
    let profileImageURL: String?
    let role: String
}

// MARK: - Ceremony Schedule Item

struct CeremonyScheduleItem: Identifiable, Codable {
    let id: String
    let categoryId: String
    let categoryName: String
    let time: String
    let isCompleted: Bool
    let isCurrentlyPresenting: Bool
    let winnerName: String?
}

// MARK: - Award Ceremony Manager

@MainActor
final class AwardCeremonyManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AwardCeremonyManager()
    private init() {}
    
    // MARK: - Published State
    @Published var isLive: Bool = false
    @Published var streamURL: URL?
    @Published var viewerCount: Int = 0
    @Published var currentCategory: AwardCategory?
    @Published var latestWinner: AwardWinner?
    @Published var announcedWinners: [AwardWinner] = []
    @Published var hosts: [CeremonyHost] = []
    @Published var schedule: [CeremonyScheduleItem] = []
    @Published var ceremonyStartTime: Date?
    
    let ceremonyDescription = "Join us for the most prestigious awards in streaming! Watch live as we honor the top creators across 26 categories with a total prize pool of $175,000. The grand prize for Streamer of the Year is $50,000!"
    
    // MARK: - Private State
    private var ceremonyListener: ListenerRegistration?
    private var winnersListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    // MARK: - Connect to Ceremony
    func connectToCeremony() async {
        print("📺 [AwardCeremony] Connecting to ceremony...")
        
        await loadCeremonyInfo()
        await loadHosts()
        await loadSchedule()
        setupRealtimeListeners()
        
        // Simulate viewer count updates
        startViewerCountUpdates()
    }
    
    // MARK: - Load Ceremony Info
    private func loadCeremonyInfo() async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("ceremonies").document("streamer-awards-2025").getDocument()
            
            if let data = snapshot.data() {
                isLive = data["isLive"] as? Bool ?? false
                
                if let streamURLString = data["streamURL"] as? String {
                    streamURL = URL(string: streamURLString)
                }
                
                viewerCount = data["viewerCount"] as? Int ?? 0
                
                if let startTimestamp = data["startTime"] as? Timestamp {
                    ceremonyStartTime = startTimestamp.dateValue()
                }
                
                print("✅ [AwardCeremony] Ceremony info loaded - Live: \(isLive)")
            }
        } catch {
            print("🚨 [AwardCeremony] Error loading ceremony info: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Load Hosts
    private func loadHosts() async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("ceremony-hosts")
                .whereField("ceremonyId", isEqualTo: "streamer-awards-2025")
                .getDocuments()
            
            hosts = snapshot.documents.compactMap { doc in
                try? doc.data(as: CeremonyHost.self)
            }
            
            print("✅ [AwardCeremony] Loaded \(hosts.count) hosts")
        } catch {
            print("🚨 [AwardCeremony] Error loading hosts: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Load Schedule
    private func loadSchedule() async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("ceremony-schedule")
                .whereField("ceremonyId", isEqualTo: "streamer-awards-2025")
                .order(by: "order")
                .getDocuments()
            
            schedule = snapshot.documents.compactMap { doc in
                try? doc.data(as: CeremonyScheduleItem.self)
            }
            
            // Find current category
            if let currentItem = schedule.first(where: { $0.isCurrentlyPresenting }) {
                // Map to AwardCategory
                currentCategory = AwardCategory(
                    id: currentItem.categoryId,
                    name: currentItem.categoryName,
                    icon: "trophy.fill",
                    color: .yellow
                )
            }
            
            print("✅ [AwardCeremony] Loaded \(schedule.count) schedule items")
        } catch {
            print("🚨 [AwardCeremony] Error loading schedule: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Real-time Listeners
    private func setupRealtimeListeners() {
        #if canImport(FirebaseFirestore)
        
        // Listen to ceremony state
        ceremonyListener = db.collection("ceremonies").document("streamer-awards-2025")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🚨 [AwardCeremony] Error listening to ceremony: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    await self.loadCeremonyInfo()
                    await self.loadSchedule()
                }
            }
        
        // Listen to winner announcements
        winnersListener = db.collection("award-winners")
            .whereField("ceremonyId", isEqualTo: "streamer-awards-2025")
            .order(by: "announcedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🚨 [AwardCeremony] Error listening to winners: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let winners = documents.compactMap { doc -> AwardWinner? in
                        try? doc.data(as: AwardWinner.self)
                    }
                    
                    // Check for new winner
                    if let latestWinner = winners.first,
                       latestWinner.id != self.latestWinner?.id {
                        self.latestWinner = latestWinner
                        print("🏆 [AwardCeremony] New winner announced: \(latestWinner.winnerName)")
                    }
                    
                    self.announcedWinners = winners
                }
            }
        
        print("✅ [AwardCeremony] Real-time listeners setup")
        #endif
    }
    
    // MARK: - Viewer Count Updates
    private func startViewerCountUpdates() {
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isLive else { return }
                
                // Simulate viewer count fluctuation
                let change = Int.random(in: -50...100)
                self.viewerCount = max(0, self.viewerCount + change)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Disconnect
    func disconnect() {
        ceremonyListener?.remove()
        winnersListener?.remove()
        cancellables.removeAll()
        
        print("🛑 [AwardCeremony] Disconnected from ceremony")
    }
    
    // MARK: - Admin: Announce Winner
    func announceWinner(
        categoryId: String,
        categoryName: String,
        winnerId: String,
        winnerName: String,
        profileImageURL: String?,
        prizeAmount: String,
        voteCount: Int
    ) async throws {
        #if canImport(FirebaseFirestore)
        let winnerId = UUID().uuidString
        let winner = AwardWinner(
            id: winnerId,
            categoryId: categoryId,
            categoryName: categoryName,
            winnerId: winnerId,
            winnerName: winnerName,
            profileImageURL: profileImageURL,
            prizeAmount: prizeAmount,
            voteCount: voteCount,
            announcedAt: Date()
        )
        
        try await db.collection("award-winners").document(winnerId).setData([
            "id": winner.id,
            "ceremonyId": "streamer-awards-2025",
            "categoryId": winner.categoryId,
            "categoryName": winner.categoryName,
            "winnerId": winner.winnerId,
            "winnerName": winner.winnerName,
            "profileImageURL": winner.profileImageURL as Any,
            "prizeAmount": winner.prizeAmount,
            "voteCount": winner.voteCount,
            "announcedAt": FieldValue.serverTimestamp()
        ])
        
        // Update schedule
        try await db.collection("ceremony-schedule")
            .whereField("categoryId", isEqualTo: categoryId)
            .getDocuments()
            .documents.first?
            .reference.updateData([
                "isCompleted": true,
                "isCurrentlyPresenting": false,
                "winnerName": winnerName
            ])
        
        print("✅ [AwardCeremony] Winner announced: \(winnerName) for \(categoryName)")
        
        // Send notifications to all viewers
        await notifyViewers(winner: winner)
        
        #endif
    }
    
    // MARK: - Notifications
    private func notifyViewers(winner: AwardWinner) async {
        // Send push notifications to all ceremony viewers
        print("📱 [AwardCeremony] Notifying viewers of winner: \(winner.winnerName)")
        // Implement via NotificationManager or Firebase Cloud Messaging
    }
    
    deinit {
        // Note: Cannot call disconnect() from deinit (MainActor isolation)
        // Make sure to call disconnect() before manager is deallocated
        print("✅ [AwardCeremony] Manager deallocated")
    }
}

