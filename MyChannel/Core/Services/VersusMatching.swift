//
//  VersusMatching.swift
//  MyChannel
//
//  Protocol abstraction for VS Match lifecycle — enables DI mocks in tests.
//

import Foundation

/// Create, fetch, and settle versus matches.
@MainActor
protocol VersusMatching: AnyObject {
    func createMatch(
        challengerId: String,
        opponentId: String,
        matchType: VersusMatch.MatchType,
        wagerAmount: Double,
        category: VersusMatch.Category,
        rules: VersusMatch.MatchRules,
        scheduledDate: Date
    ) async throws -> VersusMatch

    func fetchMatch(matchId: String) async -> VersusMatch?
}
