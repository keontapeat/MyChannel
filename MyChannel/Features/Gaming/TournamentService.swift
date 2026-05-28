//
//  TournamentService.swift
//  MyChannel
//
//  🏆 TOURNAMENT SERVICE - Manages tournaments & brackets with Firestore! 🔥
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class TournamentService: ObservableObject {
    static let shared = TournamentService()
    
    @Published var activeTournaments: [BracketTournament] = []
    @Published var upcomingTournaments: [BracketTournament] = []
    @Published var completedTournaments: [BracketTournament] = []
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    private init() {
        loadActiveTournaments()
    }
    
    // MARK: - 🔥 LOAD TOURNAMENTS
    
    func loadActiveTournaments() {
        Task {
            await fetchActiveTournaments()
        }
    }
    
    func fetchActiveTournaments() async {
        #if canImport(FirebaseFirestore)
        do {
            // Fetch active tournaments
            let snapshot = try await db.collection("tournaments")
                .whereField("status", isEqualTo: "active")
                .order(by: "startDate", descending: false)
                .getDocuments()
            
            var tournaments: [BracketTournament] = []
            
            for doc in snapshot.documents {
                if let tournament = try? await parseTournament(doc: doc) {
                    tournaments.append(tournament)
                }
            }
            
            activeTournaments = tournaments
            
            // Fetch upcoming tournaments
            let upcomingSnapshot = try await db.collection("tournaments")
                .whereField("status", isEqualTo: "upcoming")
                .order(by: "startDate", descending: false)
                .getDocuments()
            
            var upcoming: [BracketTournament] = []
            for doc in upcomingSnapshot.documents {
                if let tournament = try? await parseTournament(doc: doc) {
                    upcoming.append(tournament)
                }
            }
            
            upcomingTournaments = upcoming
            
            print("✅ Loaded \(tournaments.count) active tournaments")
            
        } catch {
            print("🚨 Error loading tournaments: \(error)")
            // Fallback to sample data if Firestore fails
            activeTournaments = [BracketTournament.sample]
        }
        #else
        // Fallback to sample data
        activeTournaments = [BracketTournament.sample]
        #endif
    }
    
    // MARK: - 📊 PARSE TOURNAMENT
    
    #if canImport(FirebaseFirestore)
    private func parseTournament(doc: DocumentSnapshot) async throws -> BracketTournament {
        let data = doc.data() ?? [:]
        
        let tournamentId = doc.documentID
        let name = data["name"] as? String ?? "Tournament"
        let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
        let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(604800)
        let prizePool = data["prizePool"] as? Double ?? 0
        
        // Load rounds from subcollection
        let roundsSnapshot = try await db.collection("tournaments")
            .document(tournamentId)
            .collection("rounds")
            .order(by: "roundNumber", descending: false)
            .getDocuments()
        
        var rounds: [BracketRound] = []
        
        for roundDoc in roundsSnapshot.documents {
            let roundData = roundDoc.data()
            let roundNumber = roundData["roundNumber"] as? Int ?? 0
            let roundName = roundData["roundName"] as? String ?? "Round \(roundNumber)"
            let matchesData = roundData["matches"] as? [[String: Any]] ?? []
            
            var matches: [BracketMatch] = []
            
            for matchData in matchesData {
                let matchId = matchData["matchId"] as? String ?? UUID().uuidString
                let team1Id = matchData["team1Id"] as? String ?? ""
                let team1Name = matchData["team1Name"] as? String ?? "Team 1"
                let team2Id = matchData["team2Id"] as? String ?? ""
                let team2Name = matchData["team2Name"] as? String ?? "Team 2"
                let winnerId = matchData["winnerId"] as? String
                let isCompleted = matchData["isCompleted"] as? Bool ?? false
                let score1 = matchData["score1"] as? Int
                let score2 = matchData["score2"] as? Int
                let scheduledDate = (matchData["scheduledDate"] as? Timestamp)?.dateValue()
                
            let team1 = BracketTeam(id: team1Id, name: team1Name)
            let team2 = team2Id.isEmpty ? nil : BracketTeam(id: team2Id, name: team2Name)
                
                let winnerTeam: BracketTeam? = winnerId != nil ? BracketTeam(id: winnerId!, name: winnerId == team1Id ? team1Name : team2Name) : nil
                
                let match = BracketMatch(
                    id: matchId,
                    team1: team1,
                    team2: team2,
                    score1: score1,
                    score2: score2,
                    winner: winnerTeam,
                    isLive: !isCompleted
                )
                
                matches.append(match)
            }
            
            let round = BracketRound(
                id: roundDoc.documentID,
                name: roundName,
                matches: matches
            )
            
            rounds.append(round)
        }
        
        // If no rounds exist, create empty rounds structure
        if rounds.isEmpty {
            rounds = createEmptyRounds()
        }
        
        return BracketTournament(
            id: tournamentId,
            name: name,
            prizePool: prizePool,
            totalPlayers: 0, // TODO: Calculate from rounds
            rounds: rounds,
            startDate: startDate
        )
    }
    #endif
    
    // MARK: - 🎮 CREATE TOURNAMENT
    
    func createTournament(
        name: String,
        participants: [String], // User IDs
        participantNames: [String], // User display names
        prizePool: Double,
        startDate: Date
    ) async throws -> BracketTournament {
        #if canImport(FirebaseFirestore)
        let tournamentId = UUID().uuidString
        
        // Create tournament document
        try await db.collection("tournaments").document(tournamentId).setData([
            "name": name,
            "status": "upcoming",
            "prizePool": prizePool,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: startDate.addingTimeInterval(604800)), // 7 days
            "createdAt": FieldValue.serverTimestamp(),
            "participantCount": participants.count
        ])
        
        // Generate bracket rounds
        let rounds = generateBracketRounds(participants: participants, participantNames: participantNames)
        
        // Save rounds to Firestore
        for (index, round) in rounds.enumerated() {
            let roundData: [String: Any] = [
                "roundNumber": index + 1,
                "roundName": round.name,
                "matches": round.matches.map { (match: BracketMatch) -> [String: Any] in
                    [
                        "matchId": match.id,
                        "team1Id": match.team1.id,
                        "team1Name": match.team1.name,
                    "team2Id": match.team2?.id ?? "",
                    "team2Name": match.team2?.name ?? "",
                    "winnerId": match.winner?.id ?? NSNull(),
                    "isCompleted": match.winner != nil,
                    "score1": match.score1 ?? NSNull(),
                    "score2": match.score2 ?? NSNull(),
                    "scheduledDate": NSNull()
                    ]
                }
            ]
            
            try await db.collection("tournaments")
                .document(tournamentId)
                .collection("rounds")
                .document("round-\(index + 1)")
                .setData(roundData)
        }
        
        // Load the created tournament
        if let doc = try? await db.collection("tournaments").document(tournamentId).getDocument() {
            if let tournament = try? await parseTournament(doc: doc) {
                return tournament
            }
        }
        
        throw TournamentError.failedToCreate
        #else
        return Tournament.sample
        #endif
    }
    
    // MARK: - 🏆 UPDATE MATCH RESULT
    
    func updateMatchResult(
        tournamentId: String,
        roundNumber: Int,
        matchId: String,
        winnerId: String,
        score1: Int,
        score2: Int
    ) async throws {
        #if canImport(FirebaseFirestore)
        // Update match in Firestore
        let roundRef = db.collection("tournaments")
            .document(tournamentId)
            .collection("rounds")
            .document("round-\(roundNumber)")
        
        let roundDoc = try await roundRef.getDocument()
        guard var roundData = roundDoc.data() else {
            throw TournamentError.roundNotFound
        }
        
        var matches = roundData["matches"] as? [[String: Any]] ?? []
        
        // Find and update the match
        if let matchIndex = matches.firstIndex(where: { ($0["matchId"] as? String) == matchId }) {
            matches[matchIndex]["winnerId"] = winnerId
            matches[matchIndex]["isCompleted"] = true
            matches[matchIndex]["score1"] = score1
            matches[matchIndex]["score2"] = score2
            
            roundData["matches"] = matches
            try await roundRef.setData(roundData)
            
            // Advance winner to next round if not finals
            if roundNumber < 4 {
                try await advanceWinner(
                    tournamentId: tournamentId,
                    currentRound: roundNumber,
                    winnerId: winnerId
                )
            }
            
            print("✅ Match result updated!")
        }
        #endif
    }
    
    // MARK: - ⬆️ ADVANCE WINNER
    
    #if canImport(FirebaseFirestore)
    private func advanceWinner(
        tournamentId: String,
        currentRound: Int,
        winnerId: String
    ) async throws {
        let nextRoundNumber = currentRound + 1
        let nextRoundRef = db.collection("tournaments")
            .document(tournamentId)
            .collection("rounds")
            .document("round-\(nextRoundNumber)")
        
        let nextRoundDoc = try await nextRoundRef.getDocument()
        guard var nextRoundData = nextRoundDoc.data() else {
            return
        }
        
        var matches = nextRoundData["matches"] as? [[String: Any]] ?? []
        
        // Find the first incomplete match in next round
        if let matchIndex = matches.firstIndex(where: { ($0["isCompleted"] as? Bool) == false }) {
            // Determine if winner goes to team1 or team2 based on match position
            let isTeam1 = matchIndex % 2 == 0
            if isTeam1 {
                matches[matchIndex]["team1Id"] = winnerId
                // TODO: Load team name from user data
                matches[matchIndex]["team1Name"] = "Winner from Round \(currentRound)"
            } else {
                matches[matchIndex]["team2Id"] = winnerId
                matches[matchIndex]["team2Name"] = "Winner from Round \(currentRound)"
            }
            
            nextRoundData["matches"] = matches
            try await nextRoundRef.setData(nextRoundData)
        }
    }
    #endif
    
    // MARK: - 🎯 GENERATE BRACKET ROUNDS
    
    private func generateBracketRounds(participants: [String], participantNames: [String]) -> [BracketRound] {
        let participantCount = participants.count
        guard participantCount >= 2 else {
            return []
        }
        let numRounds = Int(ceil(log2(Double(participantCount))))
        
        var rounds: [BracketRound] = []
        
        // Round 1: Pair up all participants
        var currentParticipants = participants
        var currentNames = participantNames
        
        // Fill to power of 2 with byes
        let targetCount = Int(pow(2.0, Double(numRounds)))
        while currentParticipants.count < targetCount {
            currentParticipants.append("BYE")
            currentNames.append("BYE")
        }
        
        var round1Matches: [BracketMatch] = []
        for i in stride(from: 0, to: currentParticipants.count, by: 2) {
            let team1 = BracketTeam(id: currentParticipants[i], name: currentNames[i])
            let team2 = BracketTeam(id: currentParticipants[i + 1], name: currentNames[i + 1])
            
            let match = BracketMatch(
                id: UUID().uuidString,
                team1: team1,
                team2: team2,
                score1: nil,
                score2: nil,
                winner: nil,
                isLive: true
            )
            
            round1Matches.append(match)
        }
        
        rounds.append(BracketRound(
            id: "r1",
            name: "Round 1",
            matches: round1Matches
        ))
        
        // Create placeholder rounds
        for roundNum in 2...numRounds {
            let matchesInRound = targetCount / Int(pow(2.0, Double(roundNum)))
            var roundMatches: [BracketMatch] = []
            
            for _ in 0..<matchesInRound {
                let match = BracketMatch(
                    id: UUID().uuidString,
                    team1: BracketTeam(id: "TBD", name: "TBD"),
                    team2: BracketTeam(id: "TBD", name: "TBD"),
                    score1: nil,
                    score2: nil,
                    winner: nil,
                    isLive: false
                )
                roundMatches.append(match)
            }
            
            let roundName = roundNum == numRounds ? "Finals" : roundNum == numRounds - 1 ? "Semi-Finals" : "Round \(roundNum)"
            
            rounds.append(BracketRound(
                id: "r\(roundNum)",
                name: roundName,
                matches: roundMatches
            ))
        }
        
        return rounds
    }
    
    private func createEmptyRounds() -> [BracketRound] {
        return [
            BracketRound(id: "r1", name: "Round 1", matches: []),
            BracketRound(id: "r2", name: "Round 2", matches: []),
            BracketRound(id: "r3", name: "Semi-Finals", matches: []),
            BracketRound(id: "r4", name: "Finals", matches: [])
        ]
    }
}

// MARK: - Errors

enum TournamentError: LocalizedError {
    case failedToCreate
    case roundNotFound
    case invalidParticipantCount
    
    var errorDescription: String? {
        switch self {
        case .failedToCreate: return "Failed to create tournament"
        case .roundNotFound: return "Tournament round not found"
        case .invalidParticipantCount: return "Participant count must be a power of 2"
        }
    }
}

