//
//  Int+Abbreviated.swift
//  MyChannel
//
//  Shared count formatting helper (e.g. 12_300 -> "12.3K", 4_500_000 -> "4.5M").
//  Matches the YouTube/Instagram-style abbreviated count display used across the app.
//

import Foundation

extension Int {
    /// Abbreviated, human-readable representation of a count.
    /// Examples: 950 -> "950", 12_300 -> "12.3K", 4_500_000 -> "4.5M", 2_100_000_000 -> "2.1B".
    var abbreviated: String {
        let number = Double(self)
        let absValue = abs(number)

        switch absValue {
        case 1_000_000_000...:
            return trimmed(number / 1_000_000_000) + "B"
        case 1_000_000...:
            return trimmed(number / 1_000_000) + "M"
        case 1_000...:
            return trimmed(number / 1_000) + "K"
        default:
            return "\(self)"
        }
    }

    /// Drops a trailing ".0" so 12.0K renders as "12K" but 12.3K stays "12.3K".
    private func trimmed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
}
