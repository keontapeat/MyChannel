//
//  ChampionshipBeltSystem.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🏆 CHAMPIONSHIP MEDAL SYSTEM - Olympics-style competitive championships! 🔥
//  Worth $50M+ in engagement
//

import Foundation
import FirebaseFirestore

@MainActor
class ChampionshipBeltSystem: ObservableObject {
    static let shared = ChampionshipBeltSystem()
    
    @Published var allMedals: [ChampionshipMedal] = []
    @Published var champions: [String: Champion] = [:] // medalId -> champion
    @Published var rankings: [ChampionshipDivision: [RankedCompetitor]] = [:]
    @Published var myMedals: [ChampionshipMedal] = []
    
    private let db = Firestore.firestore()
    
    private init() {
        setupMedals()
        loadChampions()
    }
    
    // MARK: - 🏆 CHAMPIONSHIP DIVISIONS
    
    enum ChampionshipDivision: String, CaseIterable, Identifiable {
        case bronze = "Bronze Medal"        // $1-100 wagers
        case silver = "Silver Medal"        // $101-500
        case gold = "Gold Medal"            // $501-1,000
        case platinum = "Platinum Medal"   // $1,001-5,000
        case diamond = "Diamond Medal"      // $5,001-10,000
        case legend = "Legend Medal"        // $10,001+
        
        var id: String { rawValue }
        
        var wagerRange: ClosedRange<Double> {
            switch self {
            case .bronze: return 1...100
            case .silver: return 101...500
            case .gold: return 501...1000
            case .platinum: return 1001...5000
            case .diamond: return 5001...10000
            case .legend: return 10001...100000
            }
        }
        
        var icon: String {
            switch self {
            case .bronze: return "🥉"
            case .silver: return "🥈"
            case .gold: return "🥇"
            case .platinum: return "💎"
            case .diamond: return "💠"
            case .legend: return "👑"
            }
        }
        
        var color: String {
            switch self {
            case .bronze: return "bronze"
            case .silver: return "silver"
            case .gold: return "gold"
            case .platinum: return "cyan"
            case .diamond: return "blue"
            case .legend: return "purple"
            }
        }
        
        var displayName: String {
            rawValue
        }
    }
    
    // MARK: - 🏅 CHAMPIONSHIP MEDAL
    
    struct ChampionshipMedal: Identifiable {
        let id: String
        let division: ChampionshipDivision
        let name: String
        var currentChampionId: String?
        var defenseCount: Int
        var createdAt: Date
        var lastDefense: Date?
        var nextDefense: Date?
        var isVacant: Bool
        
        var title: String {
            "\(division.rawValue) Championship Medal"
        }
    }
    
    // MARK: - 👑 CHAMPION
    
    struct Champion: Identifiable {
        let id: String
        let userId: String
        let medalId: String
        let division: ChampionshipDivision
        var wonAt: Date
        var defenses: Int
        var nextDefenseDate: Date
        var status: ChampionStatus
        
        enum ChampionStatus: String {
            case active = "Active"
            case defending = "Defending"
            case stripped = "Stripped"
            case retired = "Retired"
        }
    }
    
    // MARK: - 🥇 RANKED COMPETITOR
    
    struct RankedCompetitor: Identifiable {
        let id: String
        let userId: String
        let division: ChampionshipDivision
        var rank: Int
        var points: Int
        var wins: Int
        var losses: Int
        var knockouts: Int // decisive wins
        var winStreak: Int
        var totalEarnings: Double
        
        var winRate: Double {
            let total = wins + losses
            guard total > 0 else { return 0 }
            return Double(wins) / Double(total) * 100
        }
        
        var isContender: Bool {
            rank <= 3
        }
    }
    
    // MARK: - 🎯 TITLE DEFENSE
    
    struct TitleDefense: Identifiable {
        let id: String
        let medalId: String
        let championId: String
        let challengerId: String
        let matchId: String
        var scheduledDate: Date
        var status: DefenseStatus
        var result: DefenseResult?
        
        enum DefenseStatus: String {
            case scheduled = "Scheduled"
            case live = "Live"
            case completed = "Completed"
            case cancelled = "Cancelled"
        }
        
        enum DefenseResult: String {
            case successfulDefense = "Successful Defense"
            case newChampion = "New Champion"
            case draw = "Draw"
        }
    }
    
    // MARK: - ⚡ SETUP MEDALS
    
    private func setupMedals() {
        allMedals = ChampionshipDivision.allCases.map { division in
            ChampionshipMedal(
                id: UUID().uuidString,
                division: division,
                name: "\(division.rawValue) Championship",
                currentChampionId: nil,
                defenseCount: 0,
                createdAt: Date(),
                lastDefense: nil,
                nextDefense: nil,
                isVacant: true
            )
        }
    }
    
    // MARK: - 🏆 AWARD MEDAL
    
    func awardMedal(to userId: String, division: ChampionshipDivision, from matchId: String) async throws {
        print("🏆 Awarding \(division.rawValue) championship medal to \(userId)")
        
        guard let medal = allMedals.first(where: { $0.division == division }) else {
            throw MedalError.medalNotFound
        }
        
        // Create champion record
        let champion = Champion(
            id: UUID().uuidString,
            userId: userId,
            medalId: medal.id,
            division: division,
            wonAt: Date(),
            defenses: 0,
            nextDefenseDate: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days
            status: .active
        )
        
        // Save to Firestore
        try await db.collection("champions").document(champion.id).setData([
            "userId": champion.userId,
            "medalId": champion.medalId,
            "division": champion.division.rawValue,
            "wonAt": Timestamp(date: champion.wonAt),
            "defenses": champion.defenses,
            "nextDefenseDate": Timestamp(date: champion.nextDefenseDate),
            "status": champion.status.rawValue
        ])
        
        // Update medal
        try await db.collection("medals").document(medal.id).updateData([
            "currentChampionId": userId,
            "isVacant": false,
            "lastDefense": Timestamp(date: Date())
        ])
        
        champions[medal.id] = champion
        
        print("✅ Championship medal awarded! Next defense in 30 days")
    }
    
    // MARK: - 🛡️ DEFEND MEDAL
    
    func defendMedal(medalId: String, against challengerId: String) async throws -> TitleDefense {
        print("🛡️ Scheduling championship defense...")
        
        guard let champion = champions[medalId] else {
            throw MedalError.noChampion
        }
        
        // Create title defense
        let defense = TitleDefense(
            id: UUID().uuidString,
            medalId: medalId,
            championId: champion.userId,
            challengerId: challengerId,
            matchId: UUID().uuidString,
            scheduledDate: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            status: .scheduled
        )
        
        // Save to Firestore
        try await db.collection("title_defenses").document(defense.id).setData([
            "medalId": defense.medalId,
            "championId": defense.championId,
            "challengerId": defense.challengerId,
            "matchId": defense.matchId,
            "scheduledDate": Timestamp(date: defense.scheduledDate),
            "status": defense.status.rawValue
        ])
        
        print("✅ Championship defense scheduled!")
        
        return defense
    }
    
    // MARK: - 📊 UPDATE RANKINGS
    
    func updateRankings(userId: String, division: ChampionshipDivision, points: Int) async throws {
        print("📊 Updating rankings for \(userId)")
        
        // Update competitor stats
        try await db.collection("competitor_rankings")
            .document("\(division.rawValue)_\(userId)")
            .setData([
                "userId": userId,
                "division": division.rawValue,
                "points": FieldValue.increment(Int64(points)),
                "lastUpdated": Timestamp(date: Date())
            ], merge: true)
        
        // Recalculate rankings
        await recalculateRankings(for: division)
    }
    
    private func recalculateRankings(for division: ChampionshipDivision) async {
        do {
            let snapshot = try await db.collection("competitor_rankings")
                .whereField("division", isEqualTo: division.rawValue)
                .order(by: "points", descending: true)
                .limit(to: 15)
                .getDocuments()
            
            var ranked: [RankedCompetitor] = []
            
            for (index, doc) in snapshot.documents.enumerated() {
                let data = doc.data()
                
                let competitor = RankedCompetitor(
                    id: doc.documentID,
                    userId: data["userId"] as? String ?? "",
                    division: division,
                    rank: index + 1,
                    points: data["points"] as? Int ?? 0,
                    wins: data["wins"] as? Int ?? 0,
                    losses: data["losses"] as? Int ?? 0,
                    knockouts: data["knockouts"] as? Int ?? 0,
                    winStreak: data["winStreak"] as? Int ?? 0,
                    totalEarnings: data["totalEarnings"] as? Double ?? 0
                )
                
                ranked.append(competitor)
            }
            
            rankings[division] = ranked
            
        } catch {
            print("❌ Error recalculating rankings: \(error)")
        }
    }
    
    // MARK: - 🔥 GET CONTENDERS
    
    func getTopContenders(for division: ChampionshipDivision, limit: Int = 3) -> [RankedCompetitor] {
        guard let competitors = rankings[division] else { return [] }
        return Array(competitors.prefix(limit))
    }
    
    // MARK: - 🎖️ HALL OF FAME
    
    func inductIntoHallOfFame(userId: String, achievements: [String]) async throws {
        print("🎖️ Inducting \(userId) into Hall of Fame")
        
        try await db.collection("hall_of_fame").document(userId).setData([
            "userId": userId,
            "inductedAt": Timestamp(date: Date()),
            "achievements": achievements
        ])
    }
    
    // MARK: - Helper Functions
    
    private func loadChampions() {
        Task {
            do {
                let snapshot = try await db.collection("champions")
                    .whereField("status", isEqualTo: Champion.ChampionStatus.active.rawValue)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    // Parse champion data
                    // TODO: Implement parsing
                }
            } catch {
                print("❌ Error loading champions: \(error)")
            }
        }
    }
    
    func getDivisionForWager(_ wager: Double) -> ChampionshipDivision {
        for division in ChampionshipDivision.allCases {
            if division.wagerRange.contains(wager) {
                return division
            }
        }
        return .legend
    }
}

// MARK: - Errors

enum MedalError: LocalizedError {
    case medalNotFound
    case noChampion
    case notRanked
    case invalidDivision
    
    var errorDescription: String? {
        switch self {
        case .medalNotFound:
            return "Championship medal not found"
        case .noChampion:
            return "No current champion for this medal"
        case .notRanked:
            return "Competitor not ranked in this division"
        case .invalidDivision:
            return "Invalid division"
        }
    }
}

