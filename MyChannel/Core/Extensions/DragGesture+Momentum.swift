//
//  DragGesture+Momentum.swift
//  MyChannel
//
//  Convenience helpers to approximate gesture momentum without using private APIs.
//

import SwiftUI

extension DragGesture.Value {
    /// Positive when the gesture is moving downward at end, negative when moving upward.
    var verticalMomentum: CGFloat {
        predictedEndLocation.y - location.y
    }
    /// Positive when the gesture is moving to the right at end, negative to the left.
    var horizontalMomentum: CGFloat {
        predictedEndLocation.x - location.x
    }
}


