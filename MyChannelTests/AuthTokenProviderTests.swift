//
//  AuthTokenProviderTests.swift
//  MyChannelTests
//
//  Documents AuthTokenProvider fail-closed behavior when Firebase Auth is unavailable.
//

import XCTest
@testable import MyChannel

final class AuthTokenProviderTests: XCTestCase {

    func testNotSignedInThrows() async {
        // Unit test host has no signed-in Firebase user — provider must fail closed.
        do {
            _ = try await AuthTokenProvider.idToken()
            // If a test user is injected in future, skip rather than fail.
            throw XCTSkip("Firebase test user present — mock AuthTokenProvider for deterministic asserts")
        } catch let error as AuthTokenError {
            XCTAssertEqual(error, .notSignedIn)
        } catch {
            XCTFail("expected AuthTokenError.notSignedIn, got \(error)")
        }
    }

    func testAuthorizeDoesNotAttachHeaderWhenUnsigned() async {
        var request = URLRequest(url: URL(string: "https://example.com/escrow")!)
        do {
            try await AuthTokenProvider.authorize(&request)
            XCTFail("authorize should throw when unsigned")
        } catch let error as AuthTokenError {
            XCTAssertEqual(error, .notSignedIn)
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        } catch {
            XCTFail("expected AuthTokenError.notSignedIn")
        }
    }
}
