//
//  FlicksViewEvent.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import Foundation

// MARK: - Flicks Analytics Models
struct FlicksViewEvent: Codable {
    let videoId: String
    let action: FlicksViewAction
    let timestamp: Date
    let duration: TimeInterval
}

enum FlicksViewAction: String, Codable {
    case view, like, share, comment, completion, watchTime, doubleTapLike, tap, longPress, profileView
}
