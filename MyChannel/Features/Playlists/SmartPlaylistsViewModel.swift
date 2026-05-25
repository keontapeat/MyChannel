//
//  SmartPlaylistsViewModel.swift
//  MyChannel
//
//  ViewModel for AI-curated Smart Playlists
//

import Foundation
import SwiftUI

struct SmartPlaylist: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let coverImages: [String]
    let videoCount: Int
    let totalViews: Int
    let totalDuration: String
    let color: Color
    let icon: String
    let isAutoUpdating: Bool
    let aiGenerated: Bool
    let mood: String?
    let activity: String?
}

struct MoodType: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let color: Color
    
    static let allMoods: [MoodType] = [
        MoodType(id: "1", name: "Happy", emoji: "😊", color: .yellow),
        MoodType(id: "2", name: "Energetic", emoji: "⚡", color: .orange),
        MoodType(id: "3", name: "Chill", emoji: "😌", color: .blue),
        MoodType(id: "4", name: "Focus", emoji: "🎯", color: .purple),
        MoodType(id: "5", name: "Sad", emoji: "😢", color: .gray),
        MoodType(id: "6", name: "Motivated", emoji: "💪", color: .red)
    ]
}

@MainActor
class SmartPlaylistsViewModel: ObservableObject {
    @Published var aiRecommendedPlaylists: [SmartPlaylist] = []
    @Published var yourPlaylists: [SmartPlaylist] = []
    @Published var trendingPlaylists: [SmartPlaylist] = []
    @Published var activityPlaylists: [SmartPlaylist] = []
    
    func loadPlaylists() async {
        // AI Recommended (personalized based on watch history)
        aiRecommendedPlaylists = [
            SmartPlaylist(
                id: "1",
                name: "Your Daily Mix",
                description: "Based on videos you've been watching lately",
                coverImages: [],
                videoCount: 50,
                totalViews: 2500000,
                totalDuration: "8h 24m",
                color: .purple,
                icon: "star.fill",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: nil,
                activity: nil
            ),
            SmartPlaylist(
                id: "2",
                name: "Discover Weekly",
                description: "Fresh content picked just for you",
                coverImages: [],
                videoCount: 30,
                totalViews: 1800000,
                totalDuration: "5h 12m",
                color: .blue,
                icon: "cpu",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: nil,
                activity: nil
            )
        ]
        
        // Your Playlists
        yourPlaylists = [
            SmartPlaylist(
                id: "3",
                name: "Favorites",
                description: "Videos you loved",
                coverImages: [],
                videoCount: 45,
                totalViews: 5600000,
                totalDuration: "12h 30m",
                color: .red,
                icon: "heart.fill",
                isAutoUpdating: false,
                aiGenerated: false,
                mood: nil,
                activity: nil
            ),
            SmartPlaylist(
                id: "4",
                name: "Watch Later",
                description: "Save for later",
                coverImages: [],
                videoCount: 28,
                totalViews: 3200000,
                totalDuration: "6h 45m",
                color: .orange,
                icon: "clock.fill",
                isAutoUpdating: false,
                aiGenerated: false,
                mood: nil,
                activity: nil
            )
        ]
        
        // Trending
        trendingPlaylists = [
            SmartPlaylist(
                id: "5",
                name: "Viral Videos This Week",
                description: "The hottest content right now",
                coverImages: [],
                videoCount: 25,
                totalViews: 15000000,
                totalDuration: "4h 20m",
                color: .orange,
                icon: "flame.fill",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: nil,
                activity: nil
            )
        ]
        
        // Activity-based
        activityPlaylists = [
            SmartPlaylist(
                id: "6",
                name: "Workout Energy",
                description: "High-energy content for your workout",
                coverImages: [],
                videoCount: 40,
                totalViews: 4800000,
                totalDuration: "7h 15m",
                color: .red,
                icon: "figure.run",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: "energetic",
                activity: "workout"
            ),
            SmartPlaylist(
                id: "7",
                name: "Study Focus",
                description: "Content to help you concentrate",
                coverImages: [],
                videoCount: 35,
                totalViews: 3900000,
                totalDuration: "9h 30m",
                color: .purple,
                icon: "book.fill",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: "focus",
                activity: "studying"
            ),
            SmartPlaylist(
                id: "8",
                name: "Commute Time",
                description: "Perfect for your daily commute",
                coverImages: [],
                videoCount: 30,
                totalViews: 2800000,
                totalDuration: "5h 45m",
                color: .blue,
                icon: "car.fill",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: nil,
                activity: "commuting"
            ),
            SmartPlaylist(
                id: "9",
                name: "Cooking Inspiration",
                description: "Watch while you cook",
                coverImages: [],
                videoCount: 25,
                totalViews: 2200000,
                totalDuration: "4h 30m",
                color: .orange,
                icon: "fork.knife",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: nil,
                activity: "cooking"
            ),
            SmartPlaylist(
                id: "10",
                name: "Bedtime Stories",
                description: "Wind down before sleep",
                coverImages: [],
                videoCount: 20,
                totalViews: 1800000,
                totalDuration: "3h 20m",
                color: .indigo,
                icon: "moon.stars.fill",
                isAutoUpdating: true,
                aiGenerated: true,
                mood: "chill",
                activity: "sleeping"
            )
        ]
    }
}

