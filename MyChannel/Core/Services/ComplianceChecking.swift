//
//  ComplianceChecking.swift
//  MyChannel
//
//  Protocol abstraction for VS Match wagering compliance — enables DI mocks in tests.
//

import Foundation

/// Age, KYC, terms, region, and wager-limit checks before real-money play.
@MainActor
protocol ComplianceChecking: AnyObject {
    func verifyAgeForWagering(userId: String, dateOfBirth: Date) async throws -> AgeVerificationResult
    func isAgeVerified(userId: String) async -> Bool
    func startKYCVerification(userId: String) async throws -> KYCResult
    func getKYCStatus(userId: String) async -> KYCStatus
    func canUserWager(userId: String, amount: Double) async throws -> ComplianceCheckResult
    func acceptTermsOfService(userId: String, version: String) async throws
    func hasAcceptedTerms(userId: String) async -> Bool
    func isRegionAllowed(userId: String) async -> Bool
    func getAccountStatus(userId: String) async -> AccountStatus
    func getDailyWagerLimit(userId: String) async -> Double
    func getDailyWagerAmount(userId: String) async -> Double
}
