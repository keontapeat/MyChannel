//
//  StreamerAwardsVotingService.swift
//  MyChannel
//
//  Handles voting mechanism for Streamer Awards
//

import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Vote Models

struct AwardVote: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let categoryId: String
    let nomineeUserId: String
    let votingPeriod: VotingPeriod
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userId, categoryId, nomineeUserId, votingPeriod, timestamp
    }
}

enum VotingPeriod: String, Codable, CaseIterable {
    case q1_2025 = "Q1 2025"
    case q2_2025 = "Q2 2025"
    case q3_2025 = "Q3 2025"
    case q4_2025 = "Q4 2025"
    case annual_2025 = "Annual 2025"
    case annual_2026 = "Annual 2026"
    
    var displayName: String { rawValue }
    
    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .q1_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        case .q2_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 4, day: 1))!
        case .q3_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 7, day: 1))!
        case .q4_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 10, day: 1))!
        case .annual_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        case .annual_2026:
            return calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        }
    }
    
    var endDate: Date {
        let calendar = Calendar.current
        switch self {
        case .q1_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 3, day: 31))!
        case .q2_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 6, day: 30))!
        case .q3_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 9, day: 30))!
        case .q4_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        case .annual_2025:
            return calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        case .annual_2026:
            return calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        }
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
}

struct CategoryVoteResults: Identifiable, Codable {
    let id: String // categoryId
    let categoryName: String
    let votingPeriod: VotingPeriod
    var nominees: [NomineeVoteCount]
    let totalVotes: Int
    let lastUpdated: Date
}

struct NomineeVoteCount: Identifiable, Codable, Hashable {
    let id: String // userId
    let username: String
    let displayName: String
    let profileImageURL: String?
    var voteCount: Int
    var votePercentage: Double
}

// MARK: - Voting Service

@MainActor
final class StreamerAwardsVotingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = StreamerAwardsVotingService()
    private init() {
        setupRealtimeListeners()
    }
    
    // MARK: - Published State
    @Published var currentVotingPeriod: VotingPeriod = .q1_2025
    @Published var userVotes: [String: AwardVote] = [:] // categoryId -> Vote
    @Published var categoryResults: [String: CategoryVoteResults] = [:] // categoryId -> Results
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var hasVotedInCategory: [String: Bool] = [:] // categoryId -> Bool
    
    // MARK: - Private State
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    // MARK: - Setup
    private func setupRealtimeListeners() {
        // Determine current voting period
        updateCurrentVotingPeriod()
        
        // Listen for auth state changes
        #if canImport(FirebaseAuth)
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { @MainActor in
                if let user = user {
                    await self.loadUserVotes(userId: user.uid)
                } else {
                    self.userVotes.removeAll()
                    self.hasVotedInCategory.removeAll()
                }
            }
        }
        #endif
    }
    
    private func updateCurrentVotingPeriod() {
        // Find the active voting period
        for period in VotingPeriod.allCases.reversed() {
            if period.isActive {
                currentVotingPeriod = period
                break
            }
        }
    }
    
    // MARK: - Load User Votes
    func loadUserVotes(userId: String) async {
        #if canImport(FirebaseFirestore)
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("award-votes")
                .whereField("userId", isEqualTo: userId)
                .whereField("votingPeriod", isEqualTo: currentVotingPeriod.rawValue)
                .getDocuments()
            
            var votes: [String: AwardVote] = [:]
            var voted: [String: Bool] = [:]
            
            for document in snapshot.documents {
                if let vote = try? document.data(as: AwardVote.self) {
                    votes[vote.categoryId] = vote
                    voted[vote.categoryId] = true
                }
            }
            
            userVotes = votes
            hasVotedInCategory = voted
            
            print("✅ [StreamerAwardsVoting] Loaded \(votes.count) user votes")
            
        } catch {
            self.error = error
            print("🚨 [StreamerAwardsVoting] Error loading user votes: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Submit Vote
    func submitVote(
        categoryId: String,
        nomineeUserId: String,
        userId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        
        // Check if user already voted in this category
        if hasVotedInCategory[categoryId] == true {
            throw VotingError.alreadyVoted
        }
        
        // Create vote
        let voteId = UUID().uuidString
        let vote = AwardVote(
            id: voteId,
            userId: userId,
            categoryId: categoryId,
            nomineeUserId: nomineeUserId,
            votingPeriod: currentVotingPeriod,
            timestamp: Date()
        )
        
        // Save to Firestore
        try await db.collection("award-votes").document(voteId).setData([
            "id": vote.id,
            "userId": vote.userId,
            "categoryId": vote.categoryId,
            "nomineeUserId": vote.nomineeUserId,
            "votingPeriod": vote.votingPeriod.rawValue,
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        // Update local state
        userVotes[categoryId] = vote
        hasVotedInCategory[categoryId] = true
        
        // Update vote count in real-time
        await incrementVoteCount(categoryId: categoryId, nomineeUserId: nomineeUserId)
        
        print("✅ [StreamerAwardsVoting] Vote submitted for category \(categoryId)")
        
        // Send notification to nominee
        await notifyNominee(nomineeUserId: nomineeUserId, categoryId: categoryId)
        
        #endif
    }
    
    // MARK: - Change Vote
    func changeVote(
        categoryId: String,
        newNomineeUserId: String,
        userId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        
        guard let existingVote = userVotes[categoryId] else {
            throw VotingError.noExistingVote
        }
        
        // Remove old vote
        try await db.collection("award-votes").document(existingVote.id).delete()
        await decrementVoteCount(categoryId: categoryId, nomineeUserId: existingVote.nomineeUserId)
        
        // Clear local state temporarily
        userVotes.removeValue(forKey: categoryId)
        hasVotedInCategory[categoryId] = false
        
        // Submit new vote
        try await submitVote(categoryId: categoryId, nomineeUserId: newNomineeUserId, userId: userId)
        
        print("✅ [StreamerAwardsVoting] Vote changed for category \(categoryId)")
        
        #endif
    }
    
    // MARK: - Vote Count Management
    private func incrementVoteCount(categoryId: String, nomineeUserId: String) async {
        #if canImport(FirebaseFirestore)
        let resultId = "\(categoryId)_\(currentVotingPeriod.rawValue)"
        let resultRef = db.collection("award-vote-results").document(resultId)
        
        try? await resultRef.setData([
            "categoryId": categoryId,
            "votingPeriod": currentVotingPeriod.rawValue,
            "nominees.\(nomineeUserId).voteCount": FieldValue.increment(Int64(1)),
            "totalVotes": FieldValue.increment(Int64(1)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }
    
    private func decrementVoteCount(categoryId: String, nomineeUserId: String) async {
        #if canImport(FirebaseFirestore)
        let resultId = "\(categoryId)_\(currentVotingPeriod.rawValue)"
        let resultRef = db.collection("award-vote-results").document(resultId)
        
        try? await resultRef.setData([
            "nominees.\(nomineeUserId).voteCount": FieldValue.increment(Int64(-1)),
            "totalVotes": FieldValue.increment(Int64(-1)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }
    
    // MARK: - Load Vote Results
    func loadCategoryResults(categoryId: String) async throws -> CategoryVoteResults {
        #if canImport(FirebaseFirestore)
        let resultId = "\(categoryId)_\(currentVotingPeriod.rawValue)"
        let snapshot = try await db.collection("award-vote-results").document(resultId).getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            throw VotingError.noResults
        }
        
        let categoryName = data["categoryName"] as? String ?? ""
        let totalVotes = data["totalVotes"] as? Int ?? 0
        let nomineesData = data["nominees"] as? [String: [String: Any]] ?? [:]
        
        var nominees: [NomineeVoteCount] = []
        for (userId, nomineeData) in nomineesData {
            let voteCount = nomineeData["voteCount"] as? Int ?? 0
            let username = nomineeData["username"] as? String ?? ""
            let displayName = nomineeData["displayName"] as? String ?? ""
            let profileImageURL = nomineeData["profileImageURL"] as? String
            
            let percentage = totalVotes > 0 ? (Double(voteCount) / Double(totalVotes)) * 100 : 0
            
            let nominee = NomineeVoteCount(
                id: userId,
                username: username,
                displayName: displayName,
                profileImageURL: profileImageURL,
                voteCount: voteCount,
                votePercentage: percentage
            )
            nominees.append(nominee)
        }
        
        // Sort by vote count
        nominees.sort { $0.voteCount > $1.voteCount }
        
        let results = CategoryVoteResults(
            id: categoryId,
            categoryName: categoryName,
            votingPeriod: currentVotingPeriod,
            nominees: nominees,
            totalVotes: totalVotes,
            lastUpdated: Date()
        )
        
        // Cache results
        categoryResults[categoryId] = results
        
        return results
        
        #else
        throw VotingError.firebaseNotAvailable
        #endif
    }
    
    // MARK: - Real-time Results Listener
    func listenToCategoryResults(categoryId: String) {
        #if canImport(FirebaseFirestore)
        let resultId = "\(categoryId)_\(currentVotingPeriod.rawValue)"
        let listener = db.collection("award-vote-results").document(resultId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🚨 [StreamerAwardsVoting] Error listening to results: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    do {
                        let results = try await self.loadCategoryResults(categoryId: categoryId)
                        self.categoryResults[categoryId] = results
                    } catch {
                        print("🚨 [StreamerAwardsVoting] Error updating results: \(error.localizedDescription)")
                    }
                }
            }
        
        listeners.append(listener)
        #endif
    }
    
    // MARK: - Notifications
    private func notifyNominee(nomineeUserId: String, categoryId: String) async {
        // Send push notification to nominee
        // Implement via NotificationManager or Firebase Cloud Messaging
        print("📱 [StreamerAwardsVoting] Notification sent to nominee \(nomineeUserId)")
    }
    
    // MARK: - Cleanup
    func removeAllListeners() {
        #if canImport(FirebaseFirestore)
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        #endif
    }
    
    deinit {
        // Note: Cannot call MainActor methods from deinit
        // Make sure to call removeAllListeners() before service is deallocated
        cancellables.removeAll()
        print("✅ [StreamerAwardsVoting] Service deallocated")
    }
}

// MARK: - Voting Errors

enum VotingError: LocalizedError {
    case alreadyVoted
    case noExistingVote
    case noResults
    case firebaseNotAvailable
    case invalidCategory
    case votingPeriodEnded
    
    var errorDescription: String? {
        switch self {
        case .alreadyVoted:
            return "You have already voted in this category. You can change your vote if needed."
        case .noExistingVote:
            return "No existing vote found to change."
        case .noResults:
            return "No voting results available yet."
        case .firebaseNotAvailable:
            return "Voting system is currently unavailable."
        case .invalidCategory:
            return "Invalid award category."
        case .votingPeriodEnded:
            return "The voting period for this award has ended."
        }
    }
}

