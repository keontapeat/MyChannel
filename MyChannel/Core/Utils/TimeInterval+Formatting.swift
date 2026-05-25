import Foundation
import SwiftUI

extension TimeInterval {
    func formattedAsTimestamp() -> String {
        let total = Int(self.rounded())
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview("TimeInterval formattedAsTimestamp") {
    VStack(spacing: 12) {
        Text(TimeInterval(59).formattedAsTimestamp())
        Text(TimeInterval(75).formattedAsTimestamp())
        Text(TimeInterval(3605).formattedAsTimestamp())
    }
    .padding()
}