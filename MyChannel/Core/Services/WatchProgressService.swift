//
//  WatchProgressService.swift
//  MyChannel
//
//  🔥 YOUTUBE PARITY: Remember where the user left off in every video.
//  Persists to UserDefaults for instant access. Videos watched past 95%
//  are considered "finished" and won't resume.
//

import Foundation

@MainActor
final class WatchProgressService {
    static let shared = WatchProgressService()
    
    private let defaults = UserDefaults.standard
    private let storageKey = "com.mychannel.watchProgress"
    
    private init() {}
    
    // MARK: - Save Progress
    
    /// Save the current playback position for a video.
    /// Only saves if the user has watched at least 5 seconds and hasn't finished (>95%).
    func saveProgress(videoId: String, currentTime: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else { return }
        let fraction = currentTime / duration
        
        // Don't save if video just started (<5s) or is basically finished (>95%)
        guard currentTime >= 5 && fraction < 0.95 else {
            // If finished, clear the saved position so it starts from beginning next time
            if fraction >= 0.95 {
                clearProgress(videoId: videoId)
            }
            return
        }
        
        var allProgress = loadAllProgress()
        allProgress[videoId] = currentTime
        defaults.set(allProgress, forKey: storageKey)
    }
    
    // MARK: - Get Saved Position
    
    /// Returns the saved playback position for a video, or nil if none exists.
    func getSavedPosition(videoId: String) -> TimeInterval? {
        let allProgress = loadAllProgress()
        return allProgress[videoId]
    }
    
    // MARK: - Clear Progress
    
    /// Clear saved progress for a specific video (e.g., when video finishes).
    func clearProgress(videoId: String) {
        var allProgress = loadAllProgress()
        allProgress.removeValue(forKey: videoId)
        defaults.set(allProgress, forKey: storageKey)
    }
    
    // MARK: - Private
    
    private func loadAllProgress() -> [String: TimeInterval] {
        return defaults.dictionary(forKey: storageKey) as? [String: TimeInterval] ?? [:]
    }
}
