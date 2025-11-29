//
//  AudienceProfileBuilder.swift
//  MyChannel
//
//  AUDIENCE PROFILING & SEGMENTATION
//  Build detailed audience segments for targeting
//

import Foundation

@MainActor
final class AudienceProfileBuilder: ObservableObject {
    static let shared = AudienceProfileBuilder()
    
    private init() {}
    
    /// Build custom audience from user profiles
    func buildAudience(
        name: String,
        criteria: AudienceCriteria
    ) async -> CustomAudience {
        print("🎯 [AudienceBuilder] Building audience: \(name)")
        
        // Query users matching criteria
        let matchingUsers = await findMatchingUsers(criteria: criteria)
        
        let audience = CustomAudience(
            id: UUID().uuidString,
            name: name,
            description: criteria.description,
            size: matchingUsers.count,
            criteria: criteria,
            userIds: matchingUsers,
            createdAt: Date(),
            estimatedReach: estimateReach(size: matchingUsers.count)
        )
        
        print("✅ [AudienceBuilder] Audience created: \(audience.size) users")
        
        return audience
    }
    
    /// Create lookalike audience from seed users
    func createLookalikeAudience(
        seedUserIds: [String],
        expansionFactor: Double = 10.0
    ) async -> CustomAudience {
        print("🔍 [AudienceBuilder] Creating lookalike audience from \(seedUserIds.count) seeds")
        
        // Analyze seed users
        var commonInterests: [String] = []
        _ = Set<String>() // commonDemographics - reserved for future demographic analysis
        
        for userId in seedUserIds {
            if let profile = try? await AdTargetingAGI.shared.buildUserProfile(userId: userId) {
                commonInterests.append(contentsOf: profile.interests)
            }
        }
        
        // Find similar users
        _ = Int(Double(seedUserIds.count) * expansionFactor) // targetSize - for future pagination
        let criteria = AudienceCriteria(
            interests: Array(Set(commonInterests)),
            ageRanges: [],
            genders: [],
            locations: [],
            minEngagementScore: 50
        )
        
        return await buildAudience(name: "Lookalike Audience", criteria: criteria)
    }
    
    private func findMatchingUsers(criteria: AudienceCriteria) async -> [String] {
        // In production, query Firestore with criteria
        // For now, return sample
        return []
    }
    
    private func estimateReach(size: Int) -> EstimatedReach {
        let min = Int(Double(size) * 0.8)
        let max = Int(Double(size) * 1.2)
        
        return EstimatedReach(
            minimum: min,
            maximum: max,
            average: size
        )
    }
}

// MARK: - Models

struct AudienceCriteria {
    let interests: [String]
    let ageRanges: [String]
    let genders: [String]
    let locations: [String]
    let minEngagementScore: Double
    
    var description: String {
        var parts: [String] = []
        if !interests.isEmpty {
            parts.append("Interested in \(interests.prefix(3).joined(separator: ", "))")
        }
        if !ageRanges.isEmpty {
            parts.append("Age \(ageRanges.joined(separator: ", "))")
        }
        if !locations.isEmpty {
            parts.append("Located in \(locations.joined(separator: ", "))")
        }
        return parts.joined(separator: " • ")
    }
}

struct CustomAudience {
    let id: String
    let name: String
    let description: String
    let size: Int
    let criteria: AudienceCriteria
    let userIds: [String]
    let createdAt: Date
    let estimatedReach: EstimatedReach
}

struct EstimatedReach {
    let minimum: Int
    let maximum: Int
    let average: Int
}

