//
//  FlicksUserPreferences.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import Foundation

// MARK: - User Preferences
struct FlicksUserPreferences: Codable {
    var preferredCategories: [String] = []
    var preferredCreators: [String] = []
    var avgWatchTime: TimeInterval = 0
    var interactionPatterns: [String: Double] = [:]
}
