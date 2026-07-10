//
//  SnapshotPlaceholderTests.swift
//  MyChannelTests
//
//  Placeholder for snapshot / visual regression tests.
//  Enable when iOSSnapshotTestCase or swift-snapshot-testing is wired in CI.
//
//  Planned targets:
//  - ComplianceStatusBanner equivalent (VSMatchComplianceSheet)
//  - Create-match fee breakdown row
//  - Wallet balance card
//
//  Run: xcodebuild test -only-testing:MyChannelTests/SnapshotPlaceholderTests
//

import XCTest
@testable import MyChannel

final class SnapshotPlaceholderTests: XCTestCase {

    func testSnapshotInfrastructurePlaceholder() throws {
        throw XCTSkip("Snapshot tests pending — add swift-snapshot-testing or iOSSnapshotTestCase to CI")
    }
}
