//
//  Money.swift
//  MyChannel
//
//  A currency value type that stores whole cents internally so all money
//  arithmetic is exact. Use this instead of doing math on raw `Double` dollars.
//
//  Boundary note: many Firestore documents and the pay-api still represent money
//  as `Double` dollars. Convert to `Money` at the read boundary (`Money(dollars:)`),
//  do the math in `Money`, and convert back with `.dollars` only when handing a
//  value to an API that expects dollars. The server remains the source of truth.
//

import Foundation

/// An exact currency amount, stored as integer cents.
struct Money: Equatable, Hashable, Comparable, Codable {

    /// The amount in whole cents. Always an integer to avoid floating-point drift.
    private(set) var cents: Int

    init(cents: Int) {
        self.cents = cents
    }

    /// Builds a `Money` from a dollar amount (e.g. a `Double` read from Firestore),
    /// rounding to the nearest cent.
    init(dollars: Double) {
        self.cents = Int((dollars * 100).rounded())
    }

    static let zero = Money(cents: 0)

    /// The amount expressed in dollars. Use only when handing a value to an API
    /// that expects dollars — never as an intermediate for further math.
    var dollars: Double { Double(cents) / 100.0 }

    var isPositive: Bool { cents > 0 }

    // MARK: - Arithmetic (exact, in cents)

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(cents: lhs.cents + rhs.cents)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        Money(cents: lhs.cents - rhs.cents)
    }

    static func += (lhs: inout Money, rhs: Money) {
        lhs = lhs + rhs
    }

    static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.cents < rhs.cents
    }

    /// Never-negative variant — useful for fees/balances that must not go below zero.
    var clampedToZero: Money { cents < 0 ? .zero : self }

    /// Scales the amount by a fraction (e.g. a 0.90 revenue share), rounding to the
    /// nearest cent. Exact for the cent result, unlike chained `Double` multiplication.
    func fraction(_ f: Double) -> Money {
        Money(cents: Int((Double(cents) * f).rounded()))
    }

    /// Inverse of `fraction` — reconstructs a gross amount from a net share
    /// (e.g. `net.divided(by: 0.90)` → gross), rounding to the nearest cent.
    func divided(by f: Double) -> Money {
        guard f != 0 else { return .zero }
        return Money(cents: Int((Double(cents) / f).rounded()))
    }

    // MARK: - Aggregation

    /// Sums a list of amounts exactly.
    static func sum(_ amounts: [Money]) -> Money {
        Money(cents: amounts.reduce(0) { $0 + $1.cents })
    }

    // MARK: - Formatting

    /// Formats as a localized currency string (defaults to USD).
    func formatted(currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: dollars))
            ?? "$\(String(format: "%.2f", dollars))"
    }
}
