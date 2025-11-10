//
//  TournamentBracketView.swift
//  MyChannel
//
//  Tournament bracket system with scheduling
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct TournamentBracketView: View {
    
    @StateObject private var viewModel = TournamentBracketViewModel()
    let tournament: Tournament
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Tournament Header
                tournamentHeaderSection
                
                // Bracket Rounds
                ForEach(viewModel.rounds.indices, id: \.self) { roundIndex in
                    bracketRoundSection(round: viewModel.rounds[roundIndex], roundNumber: roundIndex + 1)
                }
                
                // Champion
                if let champion = viewModel.champion {
                    championSection(champion: champion)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Tournament Bracket")
        .task {
            await viewModel.loadBracket(tournamentId: tournament.id)
        }
    }
    
    // MARK: - Tournament Header
    
    private var tournamentHeaderSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(tournament.name)
                .font(AppTheme.Typography.largeTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: AppTheme.Spacing.lg) {
                Label("$\(Int(tournament.prizePool))", systemImage: "dollarsign.circle.fill")
                Label("\(tournament.maxParticipants) Players", systemImage: "person.3.fill")
                Label(tournament.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
            }
            .font(AppTheme.Typography.caption)
            .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .modernCardStyle()
    }
    
    // MARK: - Bracket Round
    
    private func bracketRoundSection(round: TournamentRound, roundNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Round Header
            HStack {
                Text(getRoundName(roundNumber: roundNumber, totalRounds: viewModel.rounds.count))
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if round.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                }
            }
            
            // Matches
            ForEach(round.matches) { match in
                matchCard(match: match)
            }
        }
        .padding(AppTheme.Spacing.md)
        .modernCardStyle()
    }
    
    // MARK: - Match Card
    
    private func matchCard(match: TournamentMatch) -> some View {
        VStack(spacing: 0) {
            // Player 1
            playerRow(
                player: match.player1,
                score: match.player1Score,
                isWinner: match.winnerId == match.player1?.id
            )
            
            Divider()
            
            // Player 2
            playerRow(
                player: match.player2,
                score: match.player2Score,
                isWinner: match.winnerId == match.player2?.id
            )
            
            // Match Info
            if let scheduledTime = match.scheduledTime {
                HStack {
                    Image(systemName: "clock")
                    Text(scheduledTime.formatted(date: .omitted, time: .shortened))
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Player Row
    
    private func playerRow(player: User?, score: Int?, isWinner: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Player Avatar
            if let player = player {
                CachedAsyncImage(url: URL(string: player.profileImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
            
            // Player Name
            Text(player?.displayName ?? "TBD")
                .font(AppTheme.Typography.body)
                .foregroundColor(isWinner ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .fontWeight(isWinner ? .semibold : .regular)
            
            Spacer()
            
            // Score
            if let score = score {
                Text("\(score)")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(isWinner ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            }
            
            // Winner Icon
            if isWinner {
                Image(systemName: "crown.fill")
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
    
    // MARK: - Champion Section
    
    private func championSection(champion: User) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("🏆 CHAMPION")
                .font(AppTheme.Typography.largeTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            CachedAsyncImage(url: URL(string: champion.profileImageURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            Text(champion.displayName)
                .font(AppTheme.Typography.title1)
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("$\(Int(tournament.prizePool)) Prize")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.success)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.Colors.primary.opacity(0.1), AppTheme.Colors.secondary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
    
    // MARK: - Helper Methods
    
    private func getRoundName(roundNumber: Int, totalRounds: Int) -> String {
        let remaining = totalRounds - roundNumber + 1
        
        switch remaining {
        case 1: return "Finals"
        case 2: return "Semi-Finals"
        case 3: return "Quarter-Finals"
        default: return "Round \(roundNumber)"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class TournamentBracketViewModel: ObservableObject {
    
    @Published var rounds: [TournamentRound] = []
    @Published var champion: User?
    @Published var isLoading = false
    
    func loadBracket(tournamentId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load bracket from Firestore
            rounds = try await TournamentService.shared.getBracket(tournamentId: tournamentId)
            
            // Check for champion (winner of finals)
            if let finals = rounds.last,
               let finalMatch = finals.matches.first,
               let winnerId = finalMatch.winnerId {
                champion = try await UserFirestoreService.shared.fetchUser(id: winnerId)
            }
            
            print("✅ [Tournament] Loaded bracket with \(rounds.count) rounds")
        } catch {
            print("🚨 [Tournament] Failed to load bracket: \(error)")
        }
    }
}

// MARK: - Supporting Service

@MainActor
final class TournamentService: ObservableObject {
    
    static let shared = TournamentService()
    private init() {}
    
    func getBracket(tournamentId: String) async throws -> [TournamentRound] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("tournaments")
            .document(tournamentId)
            .collection("brackets")
            .order(by: "roundNumber")
            .getDocuments()
        
        var rounds: [TournamentRound] = []
        
        for doc in snapshot.documents {
            let data = doc.data()
            let roundNumber = data["roundNumber"] as? Int ?? 0
            let matchesData = data["matches"] as? [[String: Any]] ?? []
            
            var matches: [TournamentMatch] = []
            for matchData in matchesData {
                let match = try parseMatch(data: matchData)
                matches.append(match)
            }
            
            let round = TournamentRound(
                roundNumber: roundNumber,
                matches: matches,
                isComplete: data["isComplete"] as? Bool ?? false
            )
            
            rounds.append(round)
        }
        
        return rounds
        #else
        return []
        #endif
    }
    
    private func parseMatch(data: [String: Any]) throws -> TournamentMatch {
        // Parse match data from Firestore
        let matchId = data["matchId"] as? String ?? UUID().uuidString
        let player1Id = data["player1Id"] as? String
        let player2Id = data["player2Id"] as? String
        
        return TournamentMatch(
            id: matchId,
            player1: nil, // TODO: Load player data
            player2: nil,
            player1Score: data["player1Score"] as? Int,
            player2Score: data["player2Score"] as? Int,
            winnerId: data["winnerId"] as? String,
            scheduledTime: (data["scheduledTime"] as? Timestamp)?.dateValue()
        )
    }
    
    /// Generate bracket for a new tournament
    func generateBracket(tournamentId: String, participants: [User]) async throws {
        guard participants.count.isPowerOfTwo else {
            throw TournamentError.invalidParticipantCount
        }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Calculate number of rounds
        let numRounds = Int(log2(Double(participants.count)))
        
        // First round: pair up all participants
        var currentMatches = participants.chunked(into: 2).map { pair -> [String: Any] in
            [
                "matchId": UUID().uuidString,
                "player1Id": pair[0].id,
                "player2Id": pair.count > 1 ? pair[1].id : "",
                "scheduledTime": Timestamp(date: Date().addingTimeInterval(3600)) // 1 hour from now
            ]
        }
        
        // Save first round
        try await db.collection("tournaments").document(tournamentId)
            .collection("brackets").document("round-1").setData([
                "roundNumber": 1,
                "matches": currentMatches,
                "isComplete": false
            ])
        
        // Create placeholder rounds
        for round in 2...numRounds {
            let numMatches = Int(pow(2.0, Double(numRounds - round)))
            let placeholderMatches = (0..<numMatches).map { _ -> [String: Any] in
                [
                    "matchId": UUID().uuidString,
                    "player1Id": "",
                    "player2Id": ""
                ]
            }
            
            try await db.collection("tournaments").document(tournamentId)
                .collection("brackets").document("round-\(round)").setData([
                    "roundNumber": round,
                    "matches": placeholderMatches,
                    "isComplete": false
                ])
        }
        
        print("✅ [Tournament] Generated bracket with \(numRounds) rounds")
        #endif
    }
}

// MARK: - Models

struct TournamentRound {
    let roundNumber: Int
    let matches: [TournamentMatch]
    let isComplete: Bool
}

struct TournamentMatch: Identifiable {
    let id: String
    let player1: User?
    let player2: User?
    var player1Score: Int?
    var player2Score: Int?
    var winnerId: String?
    var scheduledTime: Date?
}

enum TournamentError: Error {
    case invalidParticipantCount
    case bracketNotFound
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Int {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TournamentBracketView(tournament: Tournament(
            id: "test-tournament",
            name: "Weekend Championship",
            startTime: Date(),
            prizePool: 10000,
            maxParticipants: 32,
            category: "gaming"
        ))
    }
}

