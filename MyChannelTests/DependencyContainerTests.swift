//
//  DependencyContainerTests.swift
//  MyChannelTests
//
//  Smoke tests for the DI container — verifies core money/compliance
//  services resolve without trapping.
//

import XCTest
@testable import MyChannel

@MainActor
final class DependencyContainerTests: XCTestCase {

    func testResolveMoneyEscrowService() {
        let service = DependencyContainer.shared.resolve(MoneyEscrowService.self)
        XCTAssertTrue(service === MoneyEscrowService.shared)
    }

    func testResolveMoneyEscrowingProtocol() {
        let service = DependencyContainer.shared.resolve(MoneyEscrowing.self)
        XCTAssertTrue(service is MoneyEscrowService)
    }

    func testResolveVSMatchComplianceService() {
        let service = DependencyContainer.shared.resolve(VSMatchComplianceService.self)
        XCTAssertTrue(service === VSMatchComplianceService.shared)
    }

    func testResolveVSMatchWalletingProtocol() {
        let service = DependencyContainer.shared.resolve(VSMatchWalleting.self)
        XCTAssertTrue(service === VSMatchWalletService.shared)
    }

    func testResolveVersusMatchingProtocol() {
        let service = DependencyContainer.shared.resolve(VersusMatching.self)
        XCTAssertTrue(service === VersusMatchService.shared)
    }

    func testResolveStripeConnectingProtocol() {
        let service = DependencyContainer.shared.resolve(StripeConnecting.self)
        XCTAssertTrue(service === StripeConnectService.shared)
    }

    func testResolveOfflineDownloadService() {
        let service = DependencyContainer.shared.resolve(OfflineDownloadService.self)
        XCTAssertTrue(service === OfflineDownloadService.shared)
    }

    func testUnregisterUserScopedClearsCache() {
        _ = DependencyContainer.shared.resolve(VSMatchWalletService.self)
        DependencyContainer.shared.unregisterUserScopedServices()
        let again = DependencyContainer.shared.resolve(VSMatchWalletService.self)
        XCTAssertTrue(again === VSMatchWalletService.shared)
    }
}
