//
//  EsportsHubService.swift
//  MyChannel
//
//  Phase 81: Esports hub.
//  Tournaments, brackets, team pages, live-stat overlays, and integration
//  with the `mychannel-gaming-gameplay-analyzer` + `esports-ai` Cloud Run
//  services.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum EsportsGameId: String, Codable, CaseIterable {
    case valorant, leagueOfLegends, dota2, csgo, rocketLeague, fortnite, apex, overwatch2, callOfDuty
}

struct EsportsTeam: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let tag: String
    let logoURL: URL?
    let rosterUids: [String]
    let region: String
    let gameId: EsportsGameId
}

struct EsportsHubTournament: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let gameId: EsportsGameId
    let startDate: Date
    let endDate: Date
    let prizePoolUSD: Decimal
    let format: String             // "single_elim" / "double_elim" / "round_robin" / "swiss"
    let participantTeamIds: [String]
    let liveStreamId: String?
}

struct EsportsBracketMatch: Codable, Identifiable, Equatable {
    let id: String
    let tournamentId: String
    let round: Int
    let teamAId: String?
    let teamBId: String?
    let scoreA: Int?
    let scoreB: Int?
    let winnerTeamId: String?
    let scheduledAt: Date?
    let streamURL: URL?
}

@MainActor
final class EsportsHubService: ObservableObject {
    static let shared = EsportsHubService()
    private init() {}

    @Published private(set) var featuredTournaments: [EsportsHubTournament] = []
    @Published private(set) var latestBrackets: [String: [EsportsBracketMatch]] = [:]  // by tournamentId

    // MARK: - Tournaments

    func loadFeatured() async throws {
        guard AppConfig.Features.enableEsportsHub else { return }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable { let tournaments: [RawT]? }
        struct RawT: Decodable {
            let id: String
            let name: String
            let game_id: String
            let start_date: Double
            let end_date: Double
            let prize_pool_usd: Double
            let format: String
            let participant_team_ids: [String]?
            let live_stream_id: String?
        }

        let r: Raw = try await CloudRunAgentRouter.post(
            .esportsAI,
            path: "/predict",
            body: Request(task: "featured_tournaments")
        )
        featuredTournaments = (r.tournaments ?? []).compactMap { t in
            guard let game = EsportsGameId(rawValue: t.game_id) else { return nil }
            return EsportsHubTournament(
                id: t.id,
                name: t.name,
                gameId: game,
                startDate: Date(timeIntervalSince1970: t.start_date),
                endDate: Date(timeIntervalSince1970: t.end_date),
                prizePoolUSD: Decimal(t.prize_pool_usd),
                format: t.format,
                participantTeamIds: t.participant_team_ids ?? [],
                liveStreamId: t.live_stream_id
            )
        }
    }

    func loadBracket(tournamentId: String) async throws -> [EsportsBracketMatch] {
        guard AppConfig.Features.enableEsportsHub else { return [] }
        struct Request: Encodable { let task: String; let tournamentId: String }
        struct RawM: Decodable {
            let id: String
            let round: Int
            let team_a_id: String?
            let team_b_id: String?
            let score_a: Int?
            let score_b: Int?
            let winner_team_id: String?
            let scheduled_at: Double?
            let stream_url: String?
        }
        struct Raw: Decodable { let matches: [RawM]? }

        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelTournamentBracket,
            path: "/predict",
            body: Request(task: "bracket", tournamentId: tournamentId)
        )
        let list = (r.matches ?? []).map {
            EsportsBracketMatch(
                id: $0.id,
                tournamentId: tournamentId,
                round: $0.round,
                teamAId: $0.team_a_id,
                teamBId: $0.team_b_id,
                scoreA: $0.score_a,
                scoreB: $0.score_b,
                winnerTeamId: $0.winner_team_id,
                scheduledAt: $0.scheduled_at.map { Date(timeIntervalSince1970: $0) },
                streamURL: $0.stream_url.flatMap(URL.init)
            )
        }
        latestBrackets[tournamentId] = list
        return list
    }

    // MARK: - Live stat overlay feed

    /// Subscribes to a lightweight per-second stat snapshot stream used by
    /// the player overlay (kills, objectives, score). WebSocket in production;
    /// here we expose a polling fallback.
    func currentMatchStats(matchId: String) async throws -> [String: Any] {
        guard AppConfig.Features.enableEsportsHub else { return [:] }
        struct Request: Encodable { let task: String; let matchId: String }
        struct Raw: Decodable { let stats: [String: String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelGameplayAnalyzer,
            path: "/predict",
            body: Request(task: "live_stats", matchId: matchId)
        )
        return r.stats ?? [:]
    }
}
