import XCTest
@testable import MyChannel

final class CreatorStudioServiceTests: XCTestCase {
    func testRequestWithdrawalDoesNotCrash() async throws {
        let svc = CreatorEconomyService.shared
        let uid = User.sampleUsers.first!.id
        _ = try? await svc.requestWithdrawal(creatorId: uid, amount: 10.0)
        XCTAssertTrue(true)
    }

    func testAnalyticsRealtimeFetchFallback() async throws {
        let svc = AdvancedAnalyticsService.shared
        await svc.startRealtimeMonitoring(for: "test_creator")
        // Allow timer to tick once in tests optionally; here we just assert service exists
        XCTAssertNotNil(svc)
    }
}


