//
//  EsportsTournamentService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/22/25.
//  Provides Firestore-backed data for the Gaming & Esports Arena.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class EsportsTournamentService: ObservableObject {
    static let shared = EsportsTournamentService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    /// Fetch tournaments that are currently active or starting soon.
    func fetchActiveTournaments(limit: Int = 12) async throws -> [EsportsTournament] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("tournaments")
            .whereField("status", in: ["active", "upcoming", "live"])
            .order(by: "startDate", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        let tournaments: [EsportsTournament] = snapshot.documents.compactMap { doc in
            EsportsTournament(document: doc)
        }
        
        if tournaments.isEmpty {
            return Self.sampleTournaments()
        }
        
        return tournaments
        #else
        return Self.sampleTournaments()
        #endif
    }
    
    /// Fetch the highest prize pool tournament to feature.
    func fetchFeaturedTournament() async throws -> EsportsTournament? {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("tournaments")
            .whereField("status", in: ["active", "upcoming", "live"])
            .order(by: "prizePool", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        if let document = snapshot.documents.first {
            return EsportsTournament(document: document)
        }
        return nil
        #else
        return Self.sampleTournaments().first
        #endif
    }
}

// MARK: - Firestore Helpers

private extension EsportsTournament {
    #if canImport(FirebaseFirestore)
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        let startDate: Date
        if let timestamp = data["startDate"] as? Timestamp {
            startDate = timestamp.dateValue()
        } else if let startSeconds = data["startDate"] as? Double {
            startDate = Date(timeIntervalSince1970: startSeconds)
        } else {
            startDate = Date()
        }
        
        self.init(
            id: document.documentID,
            name: data["name"] as? String ?? "Tournament",
            gameName: data["gameName"] as? String ?? data["game"] as? String ?? "Multi-Game",
            prizePool: data["prizePool"] as? Double ?? 0,
            entryFee: data["entryFee"] as? Double ?? 0,
            format: data["format"] as? String ?? "Single Elimination",
            currentPlayers: data["currentPlayers"] as? Int
                ?? data["participantCount"] as? Int
                ?? 0,
            maxPlayers: data["maxPlayers"] as? Int
                ?? data["capacity"] as? Int
                ?? 0,
            startDate: startDate,
            isLive: (data["isLive"] as? Bool)
                ?? ((data["status"] as? String) == "live")
        )
    }
    #endif
}

// MARK: - Sample Fallbacks

private extension EsportsTournamentService {
    static func sampleTournaments() -> [EsportsTournament] {
        [
            EsportsTournament(
                id: "spring-championship",
                name: "Spring Championship",
                gameName: "Fortnite",
                prizePool: 50_000,
                entryFee: 50,
                format: "Single Elimination",
                currentPlayers: 248,
                maxPlayers: 256,
                startDate: Date().addingTimeInterval(60 * 60 * 48),
                isLive: false
            ),
            EsportsTournament(
                id: "pro-league-finals",
                name: "Pro League Finals",
                gameName: "Valorant",
                prizePool: 75_000,
                entryFee: 100,
                format: "Double Elimination",
                currentPlayers: 128,
                maxPlayers: 128,
                startDate: Date().addingTimeInterval(60 * 60 * 120),
                isLive: false
            )
        ]
    }
}












