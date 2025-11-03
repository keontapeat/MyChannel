//
//  FanGiftingViewModel.swift
//  MyChannel
//
//  ViewModel for Fan Gifting System
//

import Foundation
import SwiftUI

struct VirtualGift: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let price: Int // in coins
    let category: String
    let color: Color
    let animation: String
}

struct GiftCategory: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let color: Color
    
    static let allCategories: [GiftCategory] = [
        GiftCategory(id: "1", name: "Hearts", emoji: "❤️", color: .red),
        GiftCategory(id: "2", name: "Animals", emoji: "🦁", color: .orange),
        GiftCategory(id: "3", name: "Food", emoji: "🍕", color: .yellow),
        GiftCategory(id: "4", name: "Party", emoji: "🎉", color: .purple),
        GiftCategory(id: "5", name: "Premium", emoji: "💎", color: .blue)
    ]
}

struct GiftTransaction: Identifiable, Codable {
    let id: String
    let gift: VirtualGift
    let sender: String
    let recipient: String
    let sentAt: Date
    let message: String?
    let creatorEarnings: Double // 70% of gift value
}

struct TopGifter: Identifiable, Codable {
    let id: String
    let name: String
    let avatarURL: String
    let giftsGiven: Int
    let totalCoinsSpent: Int
}

@MainActor
class FanGiftingViewModel: ObservableObject {
    @Published var giftBalance: Int = 0
    @Published var popularGifts: [VirtualGift] = []
    @Published var recentGiftsSent: [GiftTransaction] = []
    @Published var giftsReceived: [GiftTransaction] = []
    @Published var topGifters: [TopGifter] = []
    @Published var isCreator: Bool = true
    @Published var totalEarningsFromGifts: Double = 0.0
    
    func loadGiftingData() async {
        // Load user's gift balance
        giftBalance = 1250
        
        // Popular gifts
        popularGifts = [
            VirtualGift(
                id: "1",
                name: "Heart",
                emoji: "❤️",
                description: "Show some love!",
                price: 10,
                category: "Hearts",
                color: .red,
                animation: "pulse"
            ),
            VirtualGift(
                id: "2",
                name: "Rose",
                emoji: "🌹",
                description: "A beautiful gesture",
                price: 25,
                category: "Hearts",
                color: .pink,
                animation: "fade"
            ),
            VirtualGift(
                id: "3",
                name: "Fire",
                emoji: "🔥",
                description: "This content is fire!",
                price: 50,
                category: "Premium",
                color: .orange,
                animation: "burst"
            ),
            VirtualGift(
                id: "4",
                name: "Diamond",
                emoji: "💎",
                description: "Premium appreciation",
                price: 100,
                category: "Premium",
                color: .blue,
                animation: "sparkle"
            ),
            VirtualGift(
                id: "5",
                name: "Crown",
                emoji: "👑",
                description: "You're the king/queen!",
                price: 200,
                category: "Premium",
                color: .yellow,
                animation: "spin"
            ),
            VirtualGift(
                id: "6",
                name: "Rocket",
                emoji: "🚀",
                description: "To the moon!",
                price: 75,
                category: "Party",
                color: .purple,
                animation: "launch"
            ),
            VirtualGift(
                id: "7",
                name: "Trophy",
                emoji: "🏆",
                description: "You won!",
                price: 150,
                category: "Premium",
                color: .yellow,
                animation: "bounce"
            ),
            VirtualGift(
                id: "8",
                name: "Party",
                emoji: "🎉",
                description: "Let's celebrate!",
                price: 30,
                category: "Party",
                color: .purple,
                animation: "confetti"
            )
        ]
        
        // Recent gifts sent
        recentGiftsSent = [
            GiftTransaction(
                id: "1",
                gift: popularGifts[0],
                sender: "You",
                recipient: "Tech Guru",
                sentAt: Date().addingTimeInterval(-3600),
                message: "Great video!",
                creatorEarnings: 0.07
            )
        ]
        
        // Gifts received (if creator)
        if isCreator {
            giftsReceived = [
                GiftTransaction(
                    id: "1",
                    gift: popularGifts[3],
                    sender: "Fan123",
                    recipient: "You",
                    sentAt: Date().addingTimeInterval(-7200),
                    message: nil,
                    creatorEarnings: 0.70
                ),
                GiftTransaction(
                    id: "2",
                    gift: popularGifts[2],
                    sender: "SuperFan",
                    recipient: "You",
                    sentAt: Date().addingTimeInterval(-10800),
                    message: "Love your content!",
                    creatorEarnings: 0.35
                )
            ]
            
            totalEarningsFromGifts = 487.50
        }
        
        // Top gifters
        topGifters = [
            TopGifter(
                id: "1",
                name: "GiftKing",
                avatarURL: "",
                giftsGiven: 234,
                totalCoinsSpent: 15600
            ),
            TopGifter(
                id: "2",
                name: "SuperFan99",
                avatarURL: "",
                giftsGiven: 189,
                totalCoinsSpent: 12400
            ),
            TopGifter(
                id: "3",
                name: "Generous1",
                avatarURL: "",
                giftsGiven: 156,
                totalCoinsSpent: 9800
            ),
            TopGifter(
                id: "4",
                name: "BigTipper",
                avatarURL: "",
                giftsGiven: 142,
                totalCoinsSpent: 8900
            ),
            TopGifter(
                id: "5",
                name: "SupporterX",
                avatarURL: "",
                giftsGiven: 128,
                totalCoinsSpent: 7500
            )
        ]
    }
}

