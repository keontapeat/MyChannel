//
//  StorySeenTracker.swift
//  MyChannel
//
//  Instagram-style local seen/unseen tracking for story rings
//

import Foundation

class StorySeenTracker: ObservableObject {
    static let shared = StorySeenTracker()
    
    private let key = "seen_story_usernames"
    
    /// Set of lowercased usernames whose stories have been fully viewed
    @Published private(set) var seenUsernames: Set<String> = []
    
    private init() {
        load()
    }
    
    // MARK: - Public API
    
    /// Check if a user's stories have been seen
    func hasSeen(username: String) -> Bool {
        seenUsernames.contains(username.lowercased())
    }
    
    /// Mark a user's stories as seen (call when their last story finishes or user taps past)
    func markSeen(username: String) {
        let key = username.lowercased()
        guard !seenUsernames.contains(key) else { return }
        seenUsernames.insert(key)
        save()
    }
    
    /// Reset a user (e.g. when they post a new story)
    func markUnseen(username: String) {
        let key = username.lowercased()
        guard seenUsernames.contains(key) else { return }
        seenUsernames.remove(key)
        save()
    }
    
    /// Clear all seen state (e.g. on logout or after 24h cleanup)
    func resetAll() {
        seenUsernames.removeAll()
        save()
    }
    
    // MARK: - Persistence
    
    private func load() {
        if let array = UserDefaults.standard.stringArray(forKey: key) {
            seenUsernames = Set(array)
        }
    }
    
    private func save() {
        UserDefaults.standard.set(Array(seenUsernames), forKey: key)
    }
}
