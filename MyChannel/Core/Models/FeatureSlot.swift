//
//  FeatureSlot.swift
//  MyChannel
//
//  Models for the ranked Feature Card (#1–#10) booking system.
//  Creators pay to occupy a ranked slot on the Home feature carousel for a
//  chosen window of dates. #1 is the most valuable (and most expensive) slot;
//  price declines as the rank number increases.
//

import Foundation
import SwiftUI

// MARK: - Feature Slot Pricing (fixed IAP price matrix)

/// Fixed price matrix for the feature card. Every (rank, duration) cell maps to
/// exactly one registered Apple In-App Purchase product, because IAP requires
/// fixed price points — you cannot charge an arbitrary amount.
///
/// All prices are kept at or under the $9,999.99 IAP ceiling. #1 for one week is
/// the flagship $5,000 spot; price declines as the rank number rises.
///
/// ⚠️ Each value below MUST have a matching Consumable IAP created in
/// App Store Connect with the product ID from `productID(rank:duration:)` and the
/// SAME price. The app reads the live price from StoreKit at runtime and only
/// falls back to these numbers for display before products load.
enum FeatureSlotPricing {
    /// [rank: [duration: USD]]
    static let matrix: [Int: [FeatureSlotDuration: Double]] = [
        1:  [.oneWeek: 5000, .twoWeeks: 8000, .oneMonth: 9999],
        2:  [.oneWeek: 2500, .twoWeeks: 4000, .oneMonth: 6500],
        3:  [.oneWeek: 1800, .twoWeeks: 3000, .oneMonth: 5000],
        4:  [.oneWeek: 1200, .twoWeeks: 2000, .oneMonth: 3500],
        5:  [.oneWeek:  900, .twoWeeks: 1500, .oneMonth: 2500],
        6:  [.oneWeek:  600, .twoWeeks: 1000, .oneMonth: 1800],
        7:  [.oneWeek:  400, .twoWeeks:  700, .oneMonth: 1200],
        8:  [.oneWeek:  250, .twoWeeks:  450, .oneMonth:  800],
        9:  [.oneWeek:  150, .twoWeeks:  250, .oneMonth:  450],
        10: [.oneWeek:   99, .twoWeeks:  170, .oneMonth:  300]
    ]

    static func price(rank: Int, duration: FeatureSlotDuration) -> Double {
        matrix[rank]?[duration] ?? 0
    }

    /// Product ID for App Store Connect, e.g. "com.mychannel.feat.slot1.1week".
    static func productID(rank: Int, duration: FeatureSlotDuration) -> String {
        "com.mychannel.feat.slot\(rank).\(duration.productSuffix)"
    }

    /// All product IDs that must exist in App Store Connect (30 consumables).
    static var allProductIDs: [String] {
        FeatureSlotTier.allRanks.flatMap { rank in
            FeatureSlotDuration.allCases.map { productID(rank: rank, duration: $0) }
        }
    }
}

// MARK: - Feature Slot Tier (rank #1–#10)

/// A single ranked slot on the feature card.
struct FeatureSlotTier: Identifiable, Hashable {
    /// 1 = top of the carousel (most expensive). 10 = last slot (cheapest).
    let rank: Int

    var id: Int { rank }
    var displayName: String { "#\(rank)" }
    var isTopSlot: Bool { rank == 1 }

    /// One-week price for this slot (used for at-a-glance display).
    var weeklyPrice: Double { FeatureSlotPricing.price(rank: rank, duration: .oneWeek) }

    /// Total number of ranked slots on the feature card.
    static let totalSlots = 10

    /// All ranks 1...10.
    static var allRanks: [Int] { Array(1...totalSlots) }

    /// All tiers, #1 → #10.
    static var ladder: [FeatureSlotTier] { allRanks.map { FeatureSlotTier(rank: $0) } }

    static func tier(forRank rank: Int) -> FeatureSlotTier? {
        (1...totalSlots).contains(rank) ? FeatureSlotTier(rank: rank) : nil
    }

    static func weeklyPrice(forRank rank: Int) -> Double {
        FeatureSlotPricing.price(rank: rank, duration: .oneWeek)
    }
}

// MARK: - Feature Slot Duration

/// How long a booking occupies its slot.
enum FeatureSlotDuration: String, Codable, CaseIterable, Identifiable {
    case oneWeek = "1_week"
    case twoWeeks = "2_weeks"
    case oneMonth = "1_month"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneWeek:  return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        }
    }

    var days: Int {
        switch self {
        case .oneWeek:  return 7
        case .twoWeeks: return 14
        case .oneMonth: return 30
        }
    }

    /// Suffix used in the IAP product ID.
    var productSuffix: String {
        switch self {
        case .oneWeek:  return "1week"
        case .twoWeeks: return "2weeks"
        case .oneMonth: return "1month"
        }
    }

    /// Fixed price for a given rank at this duration (from the IAP price matrix).
    func price(forRank rank: Int) -> Double {
        FeatureSlotPricing.price(rank: rank, duration: self)
    }
}

// MARK: - Feature Slot Booking

/// A creator's reservation of a ranked slot for a window of dates.
struct FeatureSlotBooking: Identifiable, Codable, Hashable {
    let id: String

    // Video / creator
    let videoId: String
    let creatorId: String
    let videoTitle: String
    let videoThumbnail: String
    let creatorName: String

    // Slot details
    let rank: Int
    let duration: FeatureSlotDuration
    let pricePaid: Double
    let startDate: Date
    let endDate: Date

    // State
    var paymentStatus: PaymentStatus
    var status: BookingStatus
    var paymentTransactionId: String?
    var rejectionReason: String?

    let createdAt: Date
    var updatedAt: Date

    enum PaymentStatus: String, Codable {
        case unpaid        // not charged yet (review-before-pay)
        case processing
        case completed
        case failed
        case refunded
    }

    /// Lifecycle of a booking. Review happens BEFORE payment so Apple is never
    /// charged for a video that gets rejected — no refunds, no disputes.
    enum BookingStatus: String, Codable {
        case pendingReview            // submitted, NOT charged, awaiting admin approval
        case approvedAwaitingPayment  // admin approved; creator must pay (IAP) to lock it
        case scheduled                // paid, start date in the future
        case active                   // paid, currently live on the feature card
        case completed                // window finished
        case rejected                 // admin declined (no charge ever happened)
        case cancelled                // creator/admin cancelled (frees the slot)
        case paymentExpired           // approved but creator didn't pay in time (frees slot)

        var displayName: String {
            switch self {
            case .pendingReview:           return "Pending Review"
            case .approvedAwaitingPayment: return "Approved · Pay to Lock"
            case .scheduled:               return "Scheduled"
            case .active:                  return "Live Now"
            case .completed:               return "Completed"
            case .rejected:                return "Rejected"
            case .cancelled:               return "Cancelled"
            case .paymentExpired:          return "Payment Expired"
            }
        }

        var color: Color {
            switch self {
            case .pendingReview:           return .blue
            case .approvedAwaitingPayment: return .orange
            case .scheduled:               return .purple
            case .active:                  return .green
            case .completed:               return .secondary
            case .rejected:                return .red
            case .cancelled:               return .secondary
            case .paymentExpired:          return .secondary
            }
        }
    }

    /// True if this booking holds its rank for the given window. A slot is held
    /// during review and the pay-to-lock window (so two creators can't grab the
    /// same slot/dates) and of course while scheduled/live.
    var blocksSlot: Bool {
        switch status {
        case .pendingReview, .approvedAwaitingPayment, .scheduled, .active:
            return true
        case .rejected, .cancelled, .completed, .paymentExpired:
            return false
        }
    }

    /// Creator still needs to complete IAP payment for this booking.
    var awaitingPayment: Bool { status == .approvedAwaitingPayment }

    /// Payment has cleared (slot is locked in).
    var isPaid: Bool {
        paymentStatus == .completed &&
        (status == .scheduled || status == .active || status == .completed)
    }

    /// Whether this booking's window overlaps another window for the same rank.
    func overlaps(start: Date, end: Date) -> Bool {
        startDate < end && start < endDate
    }

    /// Whether the booking window contains `date` (day-inclusive).
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        return day >= startDay && day <= endDay
    }

    var isCurrentlyLive: Bool {
        let now = Date()
        return status == .active && now >= startDate && now <= endDate
    }
}

// MARK: - Waitlist Entry

/// A creator waiting for a slot to free up. Notified when a matching slot opens.
struct FeatureSlotWaitlistEntry: Identifiable, Codable, Hashable {
    let id: String
    let videoId: String
    let creatorId: String
    let videoTitle: String
    let videoThumbnail: String
    let creatorName: String
    /// Specific rank they want, or nil for "any slot".
    let desiredRank: Int?
    /// Earliest date they'd accept a slot.
    let earliestDate: Date
    var notified: Bool
    let createdAt: Date

    var desiredRankDisplay: String {
        guard let r = desiredRank else { return "Any slot" }
        return "#\(r)"
    }
}

// MARK: - Day Availability (calendar)

/// Which ranks are taken / free on a specific calendar day.
struct FeatureSlotDayAvailability: Identifiable, Hashable {
    let date: Date
    let takenRanks: Set<Int>

    var id: Date { date }

    var availableRanks: [Int] {
        FeatureSlotTier.allRanks.filter { !takenRanks.contains($0) }
    }

    var availableCount: Int { availableRanks.count }
    var takenCount: Int { min(takenRanks.count, FeatureSlotTier.totalSlots) }
    var isFull: Bool { availableRanks.isEmpty }
    var hasAvailability: Bool { !availableRanks.isEmpty }

    /// 0...1 fill level for tinting calendar cells.
    var fillFraction: Double {
        Double(takenCount) / Double(FeatureSlotTier.totalSlots)
    }
}

// MARK: - Price Formatting

/// Formats slot prices with thousands separators and no trailing cents when whole.
enum FeatureSlotPriceFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    /// e.g. 2000 → "2,000", 99.99 → "99.99"
    static func string(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    /// e.g. "$2,000"
    static func dollar(_ value: Double) -> String {
        "$" + string(value)
    }
}
