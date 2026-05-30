import Foundation
import SwiftUI

// MARK: - LiveTV Sample Channels Index
// PERFORMANCE: Split into 8 files. ≤20 entries/file = fast type-check.
extension LiveTVChannel {
    static var sampleChannels: [LiveTVChannel] {
        _ltv01 +
        _ltv02 +
        _ltv03 +
        _ltv04 +
        _ltv05 +
        _ltv06 +
        _ltv07 +
        _ltv08
    }
}
