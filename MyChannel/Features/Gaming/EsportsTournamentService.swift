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
    func fetchActiveTournaments(limit: Int = 12) async throws -> [GamingEsportsTournament] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("tournaments")
            .whereField("status", in: ["active", "upcoming", "live"])
            .order(by: "startDate", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        let tournaments: [GamingEsportsTournament] = snapshot.documents.compactMap { doc in
            GamingEsportsTournament(document: doc)
        }
        
        if tournaments.isEmpty {
            // 🔥 DAY-ONE: No tournaments in Firestore yet — seed the starter set as
            // real, shared, joinable documents so every user sees the same live
            // content (not just a client-only fallback). Idempotent via fixed IDs.
            await seedStarterTournamentsIfNeeded()
            return Self.sampleTournaments()
        }
        
        return tournaments
        #else
        return Self.sampleTournaments()
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    /// Writes the starter tournament set to Firestore exactly once. Safe to call
    /// repeatedly: uses fixed document IDs + merge, and a guard doc to avoid
    /// re-seeding on every empty read. Only signed-in users can write (rules),
    /// so this no-ops cleanly when unauthenticated.
    private static var didAttemptSeed = false
    private func seedStarterTournamentsIfNeeded() async {
        guard !Self.didAttemptSeed else { return }
        Self.didAttemptSeed = true
        
        let now = Date()
        let hour: TimeInterval = 3600
        let starters: [(id: String, name: String, game: String, prize: Double, entry: Double, format: String, current: Int, max: Int, startOffsetHours: Double, isLive: Bool, status: String)] = [
            ("spring-championship", "Spring Championship", "Multi-Game", 50_000, 50, "Single Elimination", 248, 256, 38, false, "upcoming"),
            ("pro-league-finals", "Pro League Finals", "Fortnite", 75_000, 100, "Single Elimination", 96, 128, 125, false, "upcoming"),
            ("masters-valorant", "Masters Tournament", "Valorant", 100_000, 150, "Double Elimination", 180, 256, -2, true, "live"),
            ("rookie-rumble", "Rookie Rumble", "Rocket League", 5_000, 10, "Single Elimination", 40, 64, 12, false, "active")
        ]
        
        for t in starters {
            let startDate = now.addingTimeInterval(t.startOffsetHours * hour)
            let data: [String: Any] = [
                "name": t.name,
                "gameName": t.game,
                "prizePool": t.prize,
                "entryFee": t.entry,
                "format": t.format,
                "currentPlayers": t.current,
                "maxPlayers": t.max,
                "maxParticipants": t.max,
                "isLive": t.isLive,
                "status": t.status,
                "category": "gaming",
                "startDate": Timestamp(date: startDate),
                "startTime": Timestamp(date: startDate),
                "endDate": Timestamp(date: startDate.addingTimeInterval(604800)),
                "updatedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp()
            ]
            do {
                try await db.collection("tournaments").document(t.id).setData(data, merge: true)
            } catch {
                // Unauthenticated or offline — leave to ops seed script / next signed-in user.
                print("⚠️ Tournament self-seed skipped for \(t.id): \(error.localizedDescription)")
                return
            }
        }
        print("✅ Seeded \(starters.count) starter tournaments to Firestore")
    }
    #endif
    
    /// Join a tournament by adding the user to its participants subcollection.
    func joinTournament(tournamentId: String, userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("tournaments").document(tournamentId)
        
        // Idempotent: if the user already joined, don't double-count.
        let existing = try await ref.collection("participants").document(userId).getDocument()
        let alreadyJoined = existing.exists
        
        try await ref.collection("participants").document(userId).setData([
            "userId": userId,
            "joinedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        // 🔥 FIX: Use setData(merge:) instead of updateData so this also works for
        // tournaments whose parent doc was created lazily / by the seed tooling.
        // updateData() throws if the document doesn't exist, which silently broke
        // "JOIN" on freshly seeded tournaments.
        if !alreadyJoined {
            try await ref.setData([
                "currentPlayers": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
        #endif
    }
    
    /// Fetch the highest prize pool tournament to feature.
    func fetchFeaturedTournament() async throws -> GamingEsportsTournament? {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("tournaments")
            .whereField("status", in: ["active", "upcoming", "live"])
            .order(by: "prizePool", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        if let document = snapshot.documents.first {
            return GamingEsportsTournament(document: document)
        }
        return nil
        #else
        return Self.sampleTournaments().first
        #endif
    }
}

// MARK: - Firestore Helpers

private extension GamingEsportsTournament {
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
    static func sampleTournaments() -> [GamingEsportsTournament] {
        [
            GamingEsportsTournament(
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
            GamingEsportsTournament(
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




















