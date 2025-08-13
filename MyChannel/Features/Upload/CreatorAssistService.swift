//
//  CreatorAssistService.swift
//  MyChannel
//
//  Created by AI Assistant on 8/13/25.
//

import Foundation
import SwiftUI

struct CreatorAssistService {
    static func suggestTitle(fromExisting title: String, category: VideoCategory, duration: TimeInterval) -> String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        let minutes = max(1, Int((duration / 60).rounded()))
        switch category {
        case .technology:
            return "Top \(minutes) Tech Tips You Can Use Today"
        case .education:
            return "Learn This in \(minutes) Minutes"
        case .music:
            return "Studio Session: \(minutes)-Minute Track Breakdown"
        case .gaming:
            return "Pro Plays: \(minutes) Minutes of Next-Level Gaming"
        case .cooking:
            return "Cook This in \(minutes) Minutes"
        case .fitness:
            return "Quick \(minutes)-Minute Full-Body Workout"
        case .travel:
            return "\(minutes) Minutes in an Unforgettable City"
        case .comedy:
            return "\(minutes) Minutes of Laughs You Needed Today"
        case .entertainment, .movies, .tvShows, .anime, .documentaries, .shorts, .news, .lifestyle, .beauty, .diy, .pets, .art, .sports, .cartoons, .adultAnimation, .kids, .mukbang, .other:
            return "\(minutes)-Minute Must-Watch"
        }
    }
    
    static func suggestTags(title: String, description: String, category: VideoCategory, limit: Int = 10) -> [String] {
        var pool = Set<String>()
        let base = (title + " " + description).lowercased()
        let keywordMap: [String: [String]] = [
            "fitness": ["fitness","workout","health","routine","training","homeworkout"],
            "tech": ["tech","technology","gadgets","review","setup","productivity"],
            "music": ["music","beats","producer","studio","tutorial","cover"],
            "gaming": ["gaming","pro","clips","highlights","console","pc"],
            "education": ["learn","tutorial","guide","course","tips","howto"],
            "cooking": ["cooking","recipe","food","kitchen","chef","homemade"],
            "travel": ["travel","vlog","city","tour","adventure","hidden-gems"],
            "news": ["news","update","today","breaking","trend"],
            "comedy": ["funny","comedy","memes","shorts","skit"]
        ]
        for (k, tags) in keywordMap {
            if base.contains(k) { pool.formUnion(tags) }
        }
        pool.insert(category.displayName.lowercased())
        let words = base.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for word in words where word.count >= 4 && word.count <= 18 {
            pool.insert(word)
        }
        return Array(pool.prefix(limit))
    }
    
    static func suggestDescription(from title: String, category: VideoCategory) -> String {
        let hook = "In this video, we dive into \(title.isEmpty ? "an awesome topic" : title)."
        let value = "You'll learn practical tips and pro insights to level up fast."
        let ask = "If you found this helpful, like and subscribe for more \(category.displayName.lowercased())."
        let hashtags = "#\(category.displayName.replacingOccurrences(of: " ", with: "")) #MyChannel"
        return [hook, value, ask, "", hashtags].joined(separator: "\n")
    }
}
 
#Preview("Creator Assist Examples") {
    let title = CreatorAssistService.suggestTitle(fromExisting: "", category: .technology, duration: 245)
    let tags = CreatorAssistService.suggestTags(title: "Tech Setup", description: "Studio desk accessories", category: .technology)
    let desc = CreatorAssistService.suggestDescription(from: "Quick Tech Setup", category: .technology)
    return VStack(alignment: .leading, spacing: 8) {
        Text("Title: \(title)")
        Text("Tags: \(tags.joined(separator: ", "))")
        Text("Desc:\n\(desc)")
    }
    .padding()
}