//
//  FlicksChallengesViewModel.swift
//  MyChannel
//
//  ViewModel for Flicks Challenges
//

import Foundation
import SwiftUI

// MARK: - Models

struct FlicksChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let requirements: [String]
    let totalPrize: Int
    let startDate: Date
    let endDate: Date
    var submissions: Int
    let sponsor: ChallengeSponsor?
    
    var isActive: Bool {
        Date() >= startDate && Date() <= endDate
    }
    
    var startsIn: String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: startDate, relativeTo: Date())
    }
    
    struct ChallengeSponsor: Codable {
        let name: String
        let logoURL: String
        let amount: Int
    }
}

struct ChallengeSubmission: Identifiable, Codable {
    let id: String
    let challengeId: String
    let videoId: String
    let thumbnailURL: String
    let creator: SubmissionCreator
    let submittedAt: Date
    var aiScore: Int
    var votes: Int
    var views: Int
    var rank: Int
    var isWinner: Bool
    var prize: Int
    
    struct SubmissionCreator: Codable {
        let id: String
        let name: String
        let avatarURL: String
    }
}

struct ChallengeWinner: Identifiable, Codable {
    let id: String
    let challengeTitle: String
    let challengeId: String
    let thumbnailURL: String
    let creator: ChallengeSubmission.SubmissionCreator
    let prize: Int
    let wonDate: Date
}

// MARK: - ViewModel

@MainActor
class FlicksChallengesViewModel: ObservableObject {
    @Published var activeChallenge: FlicksChallenge?
    @Published var upcomingChallenges: [FlicksChallenge] = []
    @Published var mySubmissions: [ChallengeSubmission] = []
    @Published var topSubmissions: [ChallengeSubmission] = []
    @Published var pastWinners: [ChallengeWinner] = []
    
    @Published var totalSubmissions: Int = 0
    @Published var timeRemaining: String = "3d 5h"
    
    func loadChallenges() async {
        // Load from Firestore
        activeChallenge = FlicksChallenge(
            id: "1",
            title: "Holiday Vibes Challenge",
            description: "Create the most creative holiday-themed Flick! Show us your best holiday spirit in 60 seconds.",
            requirements: [
                "Must be 15-60 seconds",
                "Holiday theme required",
                "Original content only",
                "No copyrighted music"
            ],
            totalPrize: 100000,
            startDate: Date().addingTimeInterval(-86400 * 3),
            endDate: Date().addingTimeInterval(86400 * 4),
            submissions: 4523,
            sponsor: FlicksChallenge.ChallengeSponsor(
                name: "Nike",
                logoURL: "",
                amount: 50000
            )
        )
        
        totalSubmissions = 4523
        
        // Load submissions
        loadSubmissions()
        
        // Load upcoming
        loadUpcomingChallenges()
        
        // Load winners
        loadPastWinners()
    }
    
    private func loadSubmissions() {
        // Mock data
        mySubmissions = [
            ChallengeSubmission(
                id: "1",
                challengeId: "1",
                videoId: "v1",
                thumbnailURL: "",
                creator: ChallengeSubmission.SubmissionCreator(id: "u1", name: "You", avatarURL: ""),
                submittedAt: Date(),
                aiScore: 87,
                votes: 234,
                views: 5600,
                rank: 15,
                isWinner: false,
                prize: 0
            )
        ]
        
        topSubmissions = Array(1...50).map { i in
            ChallengeSubmission(
                id: "\(i)",
                challengeId: "1",
                videoId: "v\(i)",
                thumbnailURL: "",
                creator: ChallengeSubmission.SubmissionCreator(
                    id: "u\(i)",
                    name: "Creator \(i)",
                    avatarURL: ""
                ),
                submittedAt: Date(),
                aiScore: 95 - i,
                votes: 1000 - (i * 10),
                views: 10000 - (i * 100),
                rank: i,
                isWinner: i <= 50,
                prize: prizeForRank(i)
            )
        }
    }
    
    private func loadUpcomingChallenges() {
        upcomingChallenges = [
            FlicksChallenge(
                id: "2",
                title: "New Year's Resolution",
                description: "Share your goals for the new year",
                requirements: ["15-60 seconds", "Inspirational theme"],
                totalPrize: 75000,
                startDate: Date().addingTimeInterval(86400 * 7),
                endDate: Date().addingTimeInterval(86400 * 14),
                submissions: 0,
                sponsor: nil
            )
        ]
    }
    
    private func loadPastWinners() {
        pastWinners = [
            ChallengeWinner(
                id: "1",
                challengeTitle: "Halloween Spooktacular",
                challengeId: "prev1",
                thumbnailURL: "",
                creator: ChallengeSubmission.SubmissionCreator(
                    id: "w1",
                    name: "Sarah M.",
                    avatarURL: ""
                ),
                prize: 50000,
                wonDate: Date().addingTimeInterval(-86400 * 30)
            )
        ]
    }
    
    private func prizeForRank(_ rank: Int) -> Int {
        switch rank {
        case 1: return 50000
        case 2: return 25000
        case 3: return 15000
        case 4...10: return 1000
        case 11...50: return 100
        default: return 0
        }
    }
}


