//
//  AnalyticsService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    func trackScreenView(_ screenName: String) async {
        FirebaseManager.shared.logEvent("screen_view", parameters: ["screen_name": screenName])
    }
    
    func trackAppLaunchTime(_ time: TimeInterval) async {
        FirebaseManager.shared.logEvent("app_launch_time", parameters: ["seconds": time])
    }
    
    func trackEvent(_ eventName: String, parameters: [String: Any] = [:]) async {
        FirebaseManager.shared.logEvent(eventName, parameters: parameters)
    }

    // MARK: - Video Analytics
    func trackVideoPlay(videoId: String, position: TimeInterval) async {
        FirebaseManager.shared.logEvent("video_play", parameters: ["video_id": videoId, "position": position])
    }
    
    func trackVideoPause(videoId: String, position: TimeInterval) async {
        FirebaseManager.shared.logEvent("video_pause", parameters: ["video_id": videoId, "position": position])
    }
    
    func trackVideoSeek(videoId: String, from: TimeInterval, to: TimeInterval) async {
        FirebaseManager.shared.logEvent("video_seek", parameters: ["video_id": videoId, "from": from, "to": to])
    }
    
    func trackVideoComplete(videoId: String, duration: TimeInterval) async {
        FirebaseManager.shared.logEvent("video_complete", parameters: ["video_id": videoId, "duration": duration])
    }

    func trackChapterTap(videoId: String, title: String, start: TimeInterval) async {
        FirebaseManager.shared.logEvent("video_chapter_tap", parameters: ["video_id": videoId, "title": title, "start": start])
    }
}