//
//  TermsVersionSyncTests.swift
//  MyChannelTests
//
//  Pins the VS Match Terms version across platforms. When bumping
//  `WagerPolicy.currentTermsVersion`, also update:
//  - web-v2/lib/wager-policy.ts → WAGER_POLICY.currentTermsVersion
//  - cloud-functions/escrow-payments (server enforcement)
//  - Firestore user compliance docs (termsAcceptedVersion field)
//

import XCTest
@testable import MyChannel

final class TermsVersionSyncTests: XCTestCase {

    /// Canonical terms version — must match web and server.
    private let expectedTermsVersion = "2025.1"

    func testIOSCurrentTermsVersionMatchesCanonical() {
        XCTAssertEqual(WagerPolicy.currentTermsVersion, expectedTermsVersion,
                       "iOS WagerPolicy.currentTermsVersion must stay in sync with web-v2/lib/wager-policy.ts and escrow Cloud Functions")
    }

    func testTermsVersionFormatIsYearDotMinor() {
        let parts = WagerPolicy.currentTermsVersion.split(separator: ".")
        XCTAssertEqual(parts.count, 2, "Terms version should be YYYY.N (e.g. 2025.1)")
        XCTAssertEqual(parts[0], "2025")
    }
}
