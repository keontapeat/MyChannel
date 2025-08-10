//
//  FlicksEngagementType.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import Foundation

enum FlicksEngagementType {
    case view, like, share, comment, doubleTapLike, tap, longPress, profileView
    
    var weight: Double {
        switch self {
        case .view: return 1.0
        case .like: return 5.0
        case .doubleTapLike: return 7.0
        case .share: return 10.0
        case .comment: return 8.0
        case .tap: return 0.5
        case .longPress: return 2.0
        case .profileView: return 3.0
        }
    }
    
    func toViewAction() -> FlicksViewAction {
        switch self {
        case .view: return .view
        case .like: return .like
        case .doubleTapLike: return .doubleTapLike
        case .share: return .share
        case .comment: return .comment
        case .tap: return .tap
        case .longPress: return .longPress
        case .profileView: return .profileView
        }
    }
}
