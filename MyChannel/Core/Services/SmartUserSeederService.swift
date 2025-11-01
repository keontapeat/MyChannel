//
//  SmartUserSeederService.swift
//  MyChannel
//
//  🔥 SMART USER SEEDING SYSTEM
//  AI generates realistic users → Real users automatically replace them
//

import Foundation
import SwiftUI

/// 🔥 SMART USER SEEDING SERVICE
/// Fills the app with AI-generated realistic users until real users replace them
@MainActor
class SmartUserSeederService: ObservableObject {
    static let shared = SmartUserSeederService()
    private init() {}
    
    // MARK: - Published State
    @Published var seededUsers: [SeededUser] = []
    @Published var realUserCount: Int = 0
    @Published var mockUserCount: Int = 0
    @Published var percentageReal: Double = 0.0 // % of real users
    
    // MARK: - User Types
    enum UserType: String, Codable {
        case real        // Actual user who signed up
        case aiGenerated // AI-generated for seeding
        case imported    // Imported from your IG friends list
    }
    
    // MARK: - Seeded User Model
    struct SeededUser: Identifiable, Codable {
        let id: String
        let username: String
        let displayName: String
        let bio: String?
        let profileImageURL: String?
        let bannerImageURL: String?
        let isVerified: Bool
        let subscriberCount: Int
        let videoCount: Int
        let totalViews: Int
        let category: ContentCategory // What they create
        let userType: UserType
        let createdAt: Date
        var priority: Int // Higher = stays longer (1-10)
        
        // Convert to User model
        func toUser() -> User {
            return User(
                id: id,
                username: username,
                displayName: displayName,
                email: "", // Mock users don't need email
                profileImageURL: profileImageURL,
                bannerImageURL: bannerImageURL,
                bio: bio,
                subscriberCount: subscriberCount,
                videoCount: videoCount,
                isVerified: isVerified,
                isCreator: true,
                createdAt: createdAt,
                totalViews: totalViews
            )
        }
    }
    
    // MARK: - Content Categories
    enum ContentCategory: String, CaseIterable, Codable {
        case music = "Music"
        case gaming = "Gaming"
        case sports = "Sports"
        case comedy = "Comedy"
        case lifestyle = "Lifestyle"
        case education = "Education"
        case tech = "Tech"
        case beauty = "Beauty"
        case fitness = "Fitness"
        case cooking = "Cooking"
        case travel = "Travel"
        case film = "Film & Animation"
        
        var emoji: String {
            switch self {
            case .music: return "🎵"
            case .gaming: return "🎮"
            case .sports: return "⚽️"
            case .comedy: return "😂"
            case .lifestyle: return "✨"
            case .education: return "📚"
            case .tech: return "💻"
            case .beauty: return "💄"
            case .fitness: return "💪"
            case .cooking: return "🍳"
            case .travel: return "✈️"
            case .film: return "🎬"
            }
        }
    }
    
    // MARK: - Initialization
    func initialize() async {
        print("🌱 Initializing Smart User Seeder...")
        
        // Load existing seeded users from storage
        loadSeededUsers()
        
        // Count real vs mock users
        await updateUserCounts()
        
        // If we don't have enough users, seed more
        if seededUsers.count < 50 {
            await seedInitialUsers()
        }
        
        // Auto-promote real users and demote mocks
        await balanceUserMix()
        
        print("✅ Seeded \(seededUsers.count) users (\(realUserCount) real, \(mockUserCount) mock)")
    }
    
    // MARK: - Seed Initial Users
    private func seedInitialUsers() async {
        print("🤖 Generating AI users with Claude, Gemini, and GPT-4...")
        
        // 1. Import your IG friends (priority 10 - never remove)
        await importIGFriends()
        
        // 2. Generate diverse AI users for each category
        for category in ContentCategory.allCases {
            await generateUsersForCategory(category, count: 4)
        }
        
        // 3. Generate some "rising stars" (high engagement, low subs)
        await generateRisingStars(count: 10)
        
        // Save to storage
        saveSeededUsers()
    }
    
    // MARK: - Import IG Friends
    private func importIGFriends() async {
        print("📸 Importing Instagram friends...")
        
        let friends = OwnerProfile.instagramFriends
        
        for friend in friends {
            let seededUser = SeededUser(
                id: "ig_\(friend.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                username: friend.name.lowercased().replacingOccurrences(of: " ", with: ""),
                displayName: friend.name,
                bio: "Artist from Flint, MI 🔥",
                profileImageURL: friend.avatar,
                bannerImageURL: nil,
                isVerified: true, // Your friends are verified!
                subscriberCount: Int.random(in: 10_000...100_000),
                videoCount: Int.random(in: 15...50),
                totalViews: Int.random(in: 100_000...1_000_000),
                category: .music,
                userType: .imported,
                createdAt: Date(),
                priority: 10 // NEVER remove your friends!
            )
            
            if !seededUsers.contains(where: { $0.id == seededUser.id }) {
                seededUsers.append(seededUser)
            }
        }
    }
    
    // MARK: - Generate Users for Category
    private func generateUsersForCategory(_ category: ContentCategory, count: Int) async {
        print("🤖 Generating \(count) \(category.rawValue) creators...")
        
        for _ in 0..<count {
            // Use AI to generate realistic names
            let name = await generateRealisticName(for: category)
            let username = name.lowercased().replacingOccurrences(of: " ", with: "_")
            
            // Use AI to generate bio
            let bio = await generateBio(for: category, name: name)
            
            // Generate realistic stats
            let stats = generateRealisticStats(for: category)
            
            let seededUser = SeededUser(
                id: "ai_\(UUID().uuidString.prefix(8))",
                username: username,
                displayName: name,
                bio: bio,
                profileImageURL: "https://i.pravatar.cc/200?u=\(username)", // Random avatar
                bannerImageURL: nil,
                isVerified: stats.subscribers > 50_000, // Verify if popular
                subscriberCount: stats.subscribers,
                videoCount: stats.videos,
                totalViews: stats.views,
                category: category,
                userType: .aiGenerated,
                createdAt: Date(),
                priority: 5 // Medium priority - can be replaced
            )
            
            seededUsers.append(seededUser)
        }
    }
    
    // MARK: - Generate Rising Stars
    private func generateRisingStars(count: Int) async {
        print("⭐️ Generating \(count) rising star creators...")
        
        for _ in 0..<count {
            let category = ContentCategory.allCases.randomElement()!
            let name = await generateRealisticName(for: category)
            let username = name.lowercased().replacingOccurrences(of: " ", with: "_")
            let bio = await generateBio(for: category, name: name)
            
            // Rising stars: Low subs, high engagement!
            let subscribers = Int.random(in: 1_000...10_000)
            let videos = Int.random(in: 5...20)
            let avgViewsPerVideo = Int.random(in: 5_000...20_000) // High view ratio!
            let totalViews = videos * avgViewsPerVideo
            
            let seededUser = SeededUser(
                id: "rising_\(UUID().uuidString.prefix(8))",
                username: username,
                displayName: name,
                bio: bio,
                profileImageURL: "https://i.pravatar.cc/200?u=\(username)",
                bannerImageURL: nil,
                isVerified: false,
                subscriberCount: subscribers,
                videoCount: videos,
                totalViews: totalViews,
                category: category,
                userType: .aiGenerated,
                createdAt: Date(),
                priority: 7 // Higher priority - interesting creators!
            )
            
            seededUsers.append(seededUser)
        }
    }
    
    // MARK: - AI Name Generation
    private func generateRealisticName(for category: ContentCategory) async -> String {
        // Use AI to generate realistic names
        let prompt = """
        Generate a realistic creator name for a \(category.rawValue) content creator.
        Make it sound authentic and modern.
        Return ONLY the name, nothing else.
        Examples: "Marcus Rivera", "Ava Chen", "Jamal Thompson"
        """
        
        // Try Claude first
        if let name = try? await AnthropicService.shared.sendMessage(prompt: prompt) {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fallback: Generate from template
        return generateFallbackName(for: category)
    }
    
    private func generateFallbackName(for category: ContentCategory) -> String {
        let firstNames = ["Alex", "Jordan", "Taylor", "Casey", "Morgan", "Riley", "Avery", "Quinn", "Sage", "River"]
        let lastNames = ["Chen", "Patel", "Rivera", "Thompson", "Martinez", "Anderson", "Kim", "Williams", "Garcia", "Lee"]
        
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
    
    // MARK: - AI Bio Generation
    private func generateBio(for category: ContentCategory, name: String) async -> String {
        let prompt = """
        Generate a short, catchy bio for a \(category.rawValue) creator named \(name).
        Keep it under 100 characters.
        Make it authentic and engaging.
        Return ONLY the bio, nothing else.
        """
        
        // Try GPT-4 for bio generation
        if let bio = try? await OpenAIService.shared.chat(messages: [
            .init(role: "system", content: "You are a creative bio writer. Return ONLY the bio text."),
            .init(role: "user", content: prompt)
        ]) {
            return bio.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fallback
        return "\(category.emoji) \(category.rawValue) Creator | Making waves"
    }
    
    // MARK: - Generate Realistic Stats
    private func generateRealisticStats(for category: ContentCategory) -> (subscribers: Int, videos: Int, views: Int) {
        // Different categories have different typical stats
        let baseStats: (Int, Int, Int)
        
        switch category {
        case .music:
            baseStats = (Int.random(in: 5_000...200_000), Int.random(in: 10...60), Int.random(in: 50_000...2_000_000))
        case .gaming:
            baseStats = (Int.random(in: 10_000...500_000), Int.random(in: 50...200), Int.random(in: 100_000...5_000_000))
        case .sports:
            baseStats = (Int.random(in: 3_000...100_000), Int.random(in: 20...80), Int.random(in: 30_000...1_000_000))
        case .comedy:
            baseStats = (Int.random(in: 8_000...300_000), Int.random(in: 30...100), Int.random(in: 80_000...3_000_000))
        case .lifestyle:
            baseStats = (Int.random(in: 5_000...150_000), Int.random(in: 15...70), Int.random(in: 40_000...1_500_000))
        case .education:
            baseStats = (Int.random(in: 2_000...80_000), Int.random(in: 10...50), Int.random(in: 20_000...800_000))
        case .tech:
            baseStats = (Int.random(in: 10_000...200_000), Int.random(in: 20...60), Int.random(in: 100_000...2_000_000))
        case .beauty:
            baseStats = (Int.random(in: 8_000...250_000), Int.random(in: 25...90), Int.random(in: 70_000...2_500_000))
        case .fitness:
            baseStats = (Int.random(in: 5_000...150_000), Int.random(in: 30...100), Int.random(in: 50_000...1_500_000))
        case .cooking:
            baseStats = (Int.random(in: 4_000...120_000), Int.random(in: 20...70), Int.random(in: 40_000...1_200_000))
        case .travel:
            baseStats = (Int.random(in: 10_000...300_000), Int.random(in: 30...100), Int.random(in: 100_000...3_000_000))
        case .film:
            baseStats = (Int.random(in: 3_000...100_000), Int.random(in: 10...40), Int.random(in: 30_000...1_000_000))
        }
        
        return baseStats
    }
    
    // MARK: - Balance User Mix (Real vs Mock)
    func balanceUserMix() async {
        print("⚖️ Balancing real vs mock users...")
        
        // Count real users from Firestore
        realUserCount = await countRealUsers()
        mockUserCount = seededUsers.filter { $0.userType == .aiGenerated }.count
        
        let totalUsers = realUserCount + mockUserCount
        percentageReal = totalUsers > 0 ? (Double(realUserCount) / Double(totalUsers)) * 100 : 0
        
        print("📊 User Mix: \(realUserCount) real (\(String(format: "%.1f", percentageReal))%), \(mockUserCount) mock")
        
        // If we have enough real users, start removing low-priority mocks
        if realUserCount > 10 {
            await removeLowPriorityMocks()
        }
        
        // If we have a lot of real users, remove more aggressively
        if realUserCount > 50 {
            await removeMoreMocks()
        }
        
        // If we're mostly real users, only keep high-priority mocks
        if percentageReal > 80 {
            await keepOnlyHighPriorityMocks()
        }
    }
    
    // MARK: - Remove Low Priority Mocks
    private func removeLowPriorityMocks() async {
        print("🗑️ Removing low-priority mock users...")
        
        // Remove mocks with priority < 5
        seededUsers.removeAll { user in
            user.userType == .aiGenerated && user.priority < 5
        }
        
        saveSeededUsers()
    }
    
    private func removeMoreMocks() async {
        print("🗑️ Removing more mock users...")
        
        // Remove mocks with priority < 7
        seededUsers.removeAll { user in
            user.userType == .aiGenerated && user.priority < 7
        }
        
        saveSeededUsers()
    }
    
    private func keepOnlyHighPriorityMocks() async {
        print("🗑️ Keeping only high-priority mocks...")
        
        // Keep only priority 8+, imported friends (10), and real users
        seededUsers.removeAll { user in
            user.userType == .aiGenerated && user.priority < 8
        }
        
        saveSeededUsers()
    }
    
    // MARK: - Count Real Users
    private func countRealUsers() async -> Int {
        // In production, fetch from Firestore
        #if canImport(FirebaseFirestore)
        // TODO: Query Firestore for real user count
        // For now, return current authenticated user count (1 if logged in)
        return AuthenticationManager.shared.isAuthenticated ? 1 : 0
        #else
        return 0
        #endif
    }
    
    // MARK: - Get Mixed Users for Rankings
    func getMixedUsersForRankings(limit: Int = 20) async -> [User] {
        var allUsers: [User] = []
        
        // 1. Get real users from Firestore
        let realUsers = await fetchRealUsers()
        allUsers.append(contentsOf: realUsers)
        
        // 2. Add seeded users (converted to User models)
        let seededAsUsers = seededUsers.map { $0.toUser() }
        allUsers.append(contentsOf: seededAsUsers)
        
        // 3. Sort by a mix of engagement and priority
        allUsers.sort { user1, user2 in
            let score1 = Double(user1.subscriberCount) + Double(user1.totalViews ?? 0) * 0.1
            let score2 = Double(user2.subscriberCount) + Double(user2.totalViews ?? 0) * 0.1
            return score1 > score2
        }
        
        // 4. Return top N
        return Array(allUsers.prefix(limit))
    }
    
    private func fetchRealUsers() async -> [User] {
        // Fetch from Firestore/UserDefaults
        // For now, return current user if authenticated
        if let currentUser = AuthenticationManager.shared.currentUser {
            return [currentUser]
        }
        return []
    }
    
    // MARK: - Storage
    private func saveSeededUsers() {
        if let encoded = try? JSONEncoder().encode(seededUsers) {
            UserDefaults.standard.set(encoded, forKey: "seededUsers")
        }
    }
    
    private func loadSeededUsers() {
        if let data = UserDefaults.standard.data(forKey: "seededUsers"),
           let decoded = try? JSONDecoder().decode([SeededUser].self, from: data) {
            seededUsers = decoded
        }
    }
    
    // MARK: - Register Real User
    func registerRealUser(_ user: User) async {
        print("✅ Real user registered: \(user.displayName)")
        
        // Remove any mock user with same username
        seededUsers.removeAll { $0.username == user.username }
        
        // Update counts
        await balanceUserMix()
        
        saveSeededUsers()
    }
}

