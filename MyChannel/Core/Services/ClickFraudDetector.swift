//
//  ClickFraudDetector.swift
//  MyChannel
//
//  CLICK FRAUD DETECTOR
//  Specialized detection for click fraud schemes
//

import Foundation

@MainActor
final class ClickFraudDetector: ObservableObject {
    static let shared = ClickFraudDetector()
    
    @Published var detectedFraudClicks: Int = 0
    @Published var blockedClicks: Int = 0
    @Published var savingsForAdvertisers: Double = 0.0
    
    private var recentClicks: [String: [Date]] = [:] // IP -> timestamps
    private let clickThresholdPerMinute = 10
    private let clickThresholdPerHour = 50
    
    private init() {}
    
    /// Detect if click is fraudulent
    func detectFraud(ipAddress: String, userId: String?, adId: String) async -> (isFraud: Bool, reason: String?) {
        // Track click
        var timestamps = recentClicks[ipAddress] ?? []
        timestamps.append(Date())
        
        // Remove old timestamps (older than 1 hour)
        timestamps = timestamps.filter { Date().timeIntervalSince($0) < 3600 }
        recentClicks[ipAddress] = timestamps
        
        // Check: Too many clicks per minute
        let clicksPerMinute = timestamps.filter { Date().timeIntervalSince($0) < 60 }.count
        if clicksPerMinute > clickThresholdPerMinute {
            detectedFraudClicks += 1
            blockedClicks += 1
            return (true, "Exceeded \(clickThresholdPerMinute) clicks per minute from IP \(ipAddress)")
        }
        
        // Check: Too many clicks per hour
        if timestamps.count > clickThresholdPerHour {
            detectedFraudClicks += 1
            blockedClicks += 1
            return (true, "Exceeded \(clickThresholdPerHour) clicks per hour from IP \(ipAddress)")
        }
        
        // Check: Same IP, different users (click farm)
        // (Would need to track userId per IP)
        
        return (false, nil)
    }
    
    /// Calculate money saved for advertisers
    func calculateSavings() -> Double {
        // Assume each blocked click would cost $2 on average
        return Double(blockedClicks) * 2.0
    }
}

