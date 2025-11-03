//
//  CollabFinderViewModel.swift
//  MyChannel
//
//  ViewModel for AI-Powered Collab Finder
//

import Foundation
import SwiftUI

struct CollabCreator: Identifiable, Codable {
    let id: String
    let name: String
    let avatarURL: String
    let subscribers: String
    let avgViews: String
    let isVerified: Bool
    let category: String
    let engagementRate: Double
}

struct CollabMatch: Identifiable, Codable {
    let id: String
    let creator: CollabCreator
    let matchScore: Int
    let audienceOverlap: Int
    let projectedRevenue: String
    let projectedViews: String
    let reasons: [String]
}

struct ActiveCollab: Identifiable, Codable {
    let id: String
    let projectName: String
    let partnerName: String
    let partnerAvatarURL: String
    let status: String
    let currentRevenue: String
    let views: String
    let startDate: Date
}

struct CollabCategory: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let color: Color
    
    static let allCategories: [CollabCategory] = [
        CollabCategory(id: "1", name: "Tech", emoji: "💻", color: .blue),
        CollabCategory(id: "2", name: "Gaming", emoji: "🎮", color: .purple),
        CollabCategory(id: "3", name: "Lifestyle", emoji: "✨", color: .pink),
        CollabCategory(id: "4", name: "Education", emoji: "📚", color: .green),
        CollabCategory(id: "5", name: "Music", emoji: "🎵", color: .orange),
        CollabCategory(id: "6", name: "Comedy", emoji: "😂", color: .yellow),
        CollabCategory(id: "7", name: "Fitness", emoji: "💪", color: .red),
        CollabCategory(id: "8", name: "Beauty", emoji: "💄", color: .purple)
    ]
}

struct CollabSuccessStory: Identifiable, Codable {
    let id: String
    let creator1: String
    let creator1Avatar: String
    let creator2: String
    let creator2Avatar: String
    let projectName: String
    let totalViews: String
    let totalRevenue: String
    let subscriberGrowth: String
}

@MainActor
class CollabFinderViewModel: ObservableObject {
    @Published var aiMatches: [CollabMatch] = []
    @Published var activeCollabs: [ActiveCollab] = []
    @Published var successStories: [CollabSuccessStory] = []
    @Published var projectedMonthlyRevenue: String = "0"
    @Published var avgRevenuePerCollab: String = "0"
    
    func loadCollabData() async {
        // AI-powered matches
        aiMatches = [
            CollabMatch(
                id: "1",
                creator: CollabCreator(
                    id: "c1",
                    name: "Tech Reviewer Pro",
                    avatarURL: "",
                    subscribers: "2.4M",
                    avgViews: "350K",
                    isVerified: true,
                    category: "Tech",
                    engagementRate: 8.5
                ),
                matchScore: 94,
                audienceOverlap: 67,
                projectedRevenue: "4,200",
                projectedViews: "580K",
                reasons: [
                    "Similar audience demographics",
                    "Compatible content styles",
                    "High engagement rates"
                ]
            ),
            CollabMatch(
                id: "2",
                creator: CollabCreator(
                    id: "c2",
                    name: "Creative Studio",
                    avatarURL: "",
                    subscribers: "1.8M",
                    avgViews: "280K",
                    isVerified: true,
                    category: "Creative",
                    engagementRate: 9.2
                ),
                matchScore: 89,
                audienceOverlap: 58,
                projectedRevenue: "3,800",
                projectedViews: "490K",
                reasons: [
                    "Complementary skills",
                    "Growing subscriber base",
                    "Strong community engagement"
                ]
            ),
            CollabMatch(
                id: "3",
                creator: CollabCreator(
                    id: "c3",
                    name: "Gaming Legend",
                    avatarURL: "",
                    subscribers: "3.1M",
                    avgViews: "420K",
                    isVerified: true,
                    category: "Gaming",
                    engagementRate: 7.8
                ),
                matchScore: 85,
                audienceOverlap: 52,
                projectedRevenue: "5,100",
                projectedViews: "670K",
                reasons: [
                    "Large subscriber base",
                    "Cross-category appeal",
                    "High production value"
                ]
            )
        ]
        
        // Active collaborations
        activeCollabs = [
            ActiveCollab(
                id: "1",
                projectName: "Tech Showdown Series",
                partnerName: "Gadget Guru",
                partnerAvatarURL: "",
                status: "Recording",
                currentRevenue: "2,850",
                views: "425K",
                startDate: Date().addingTimeInterval(-86400 * 14)
            )
        ]
        
        // Success stories
        successStories = [
            CollabSuccessStory(
                id: "1",
                creator1: "Sarah Tech",
                creator1Avatar: "",
                creator2: "Mike Reviews",
                creator2Avatar: "",
                projectName: "Ultimate Setup Guide",
                totalViews: "1.2M",
                totalRevenue: "8,400",
                subscriberGrowth: "45K"
            ),
            CollabSuccessStory(
                id: "2",
                creator1: "Alex Creative",
                creator1Avatar: "",
                creator2: "Jamie Design",
                creator2Avatar: "",
                projectName: "Design Challenge",
                totalViews: "890K",
                totalRevenue: "6,200",
                subscriberGrowth: "32K"
            )
        ]
        
        // Revenue projections
        projectedMonthlyRevenue = "12,500"
        avgRevenuePerCollab = "2,800"
    }
}

