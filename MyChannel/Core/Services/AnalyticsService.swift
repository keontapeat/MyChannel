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
}