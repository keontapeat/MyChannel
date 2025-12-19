//
//  AuthenticationManagerTests.swift
//  MyChannelTests
//
//  Unit tests for AuthenticationManager
//

import XCTest
@testable import MyChannel

@MainActor
final class AuthenticationManagerTests: XCTestCase {
    
    var sut: AuthenticationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = AuthenticationManager.shared
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Given a fresh AuthenticationManager
        // Then it should have proper initial state
        XCTAssertNotNil(sut)
    }
    
    func testAuthStateEnumEquality() {
        // Test AuthState equality
        let state1 = AuthenticationManager.AuthState.unauthenticated
        let state2 = AuthenticationManager.AuthState.unauthenticated
        let state3 = AuthenticationManager.AuthState.authenticated
        let state4 = AuthenticationManager.AuthState.error("Test error")
        let state5 = AuthenticationManager.AuthState.error("Test error")
        let state6 = AuthenticationManager.AuthState.error("Different error")
        
        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
        XCTAssertEqual(state4, state5)
        XCTAssertNotEqual(state4, state6)
    }
    
    // MARK: - User Update Tests
    
    func testUpdateUser() async {
        // Given a sample user
        let testUser = User(
            id: "test-123",
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            isVerified: true,
            isCreator: true
        )
        
        // When updating user
        sut.updateUser(testUser)
        
        // Then current user should be updated
        XCTAssertEqual(sut.currentUser?.id, "test-123")
        XCTAssertEqual(sut.currentUser?.username, "testuser")
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOutClearsState() throws {
        // Given a logged in user
        let testUser = User(
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com"
        )
        sut.updateUser(testUser)
        
        // When signing out (wrap in do-catch since Firebase might not be configured)
        do {
            try sut.signOut()
        } catch {
            // Expected if Firebase isn't configured in tests
        }
        
        // Then state should be cleared
        XCTAssertNil(sut.currentUser)
        XCTAssertFalse(sut.isAuthenticated)
    }
}
