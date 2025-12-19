//
//  LoggerTests.swift
//  MyChannelTests
//
//  Unit tests for MCLogger
//

import XCTest
@testable import MyChannel

final class LoggerTests: XCTestCase {
    
    // MARK: - Log Level Tests
    
    func testLogLevelEmojis() {
        XCTAssertEqual(MCLogger.Level.debug.rawValue, "🔍")
        XCTAssertEqual(MCLogger.Level.info.rawValue, "ℹ️")
        XCTAssertEqual(MCLogger.Level.success.rawValue, "✅")
        XCTAssertEqual(MCLogger.Level.warning.rawValue, "⚠️")
        XCTAssertEqual(MCLogger.Level.error.rawValue, "❌")
        XCTAssertEqual(MCLogger.Level.critical.rawValue, "🚨")
        XCTAssertEqual(MCLogger.Level.network.rawValue, "🌐")
        XCTAssertEqual(MCLogger.Level.firebase.rawValue, "🔥")
        XCTAssertEqual(MCLogger.Level.performance.rawValue, "⚡")
        XCTAssertEqual(MCLogger.Level.payment.rawValue, "💰")
        XCTAssertEqual(MCLogger.Level.player.rawValue, "🎬")
        XCTAssertEqual(MCLogger.Level.ads.rawValue, "📺")
    }
    
    // MARK: - Category Tests
    
    func testLogCategories() {
        XCTAssertEqual(MCLogger.Category.general.rawValue, "General")
        XCTAssertEqual(MCLogger.Category.network.rawValue, "Network")
        XCTAssertEqual(MCLogger.Category.firebase.rawValue, "Firebase")
        XCTAssertEqual(MCLogger.Category.player.rawValue, "Player")
        XCTAssertEqual(MCLogger.Category.upload.rawValue, "Upload")
        XCTAssertEqual(MCLogger.Category.auth.rawValue, "Auth")
        XCTAssertEqual(MCLogger.Category.ads.rawValue, "Ads")
    }
    
    // MARK: - Logger Instance Tests
    
    func testLoggerSharedInstance() {
        let logger1 = MCLogger.shared
        let logger2 = MCLogger.shared
        
        // Should be same instance (singleton)
        XCTAssertTrue(logger1 === logger2)
    }
    
    // MARK: - Logging Methods Don't Crash
    
    func testDebugLogDoesNotCrash() {
        MCLogger.shared.debug("Test debug message")
        XCTAssertTrue(true)
    }
    
    func testInfoLogDoesNotCrash() {
        MCLogger.shared.info("Test info message")
        XCTAssertTrue(true)
    }
    
    func testSuccessLogDoesNotCrash() {
        MCLogger.shared.success("Test success message")
        XCTAssertTrue(true)
    }
    
    func testWarningLogDoesNotCrash() {
        MCLogger.shared.warning("Test warning message")
        XCTAssertTrue(true)
    }
    
    func testErrorLogDoesNotCrash() {
        MCLogger.shared.error("Test error message")
        XCTAssertTrue(true)
    }
    
    func testCriticalLogDoesNotCrash() {
        MCLogger.shared.critical("Test critical message")
        XCTAssertTrue(true)
    }
    
    func testNetworkLogDoesNotCrash() {
        MCLogger.shared.network("Test network message")
        XCTAssertTrue(true)
    }
    
    func testFirebaseLogDoesNotCrash() {
        MCLogger.shared.firebase("Test firebase message")
        XCTAssertTrue(true)
    }
    
    func testPerformanceLogDoesNotCrash() {
        MCLogger.shared.performance("Test performance message")
        XCTAssertTrue(true)
    }
    
    func testPaymentLogDoesNotCrash() {
        MCLogger.shared.payment("Test payment message")
        XCTAssertTrue(true)
    }
    
    func testPlayerLogDoesNotCrash() {
        MCLogger.shared.player("Test player message")
        XCTAssertTrue(true)
    }
    
    func testAdsLogDoesNotCrash() {
        MCLogger.shared.ads("Test ads message")
        XCTAssertTrue(true)
    }
    
    func testAILogDoesNotCrash() {
        MCLogger.shared.ai("Test AI message")
        XCTAssertTrue(true)
    }
    
    func testAuthLogDoesNotCrash() {
        MCLogger.shared.auth("Test auth message")
        XCTAssertTrue(true)
    }
    
    // MARK: - Global Function Tests
    
    func testGlobalLogFunctionsDoNotCrash() {
        logDebug("Debug")
        logInfo("Info")
        logSuccess("Success")
        logWarning("Warning")
        logError("Error")
        logNetwork("Network")
        logFirebase("Firebase")
        logPerformance("Performance")
        logPayment("Payment")
        logPlayer("Player")
        logAds("Ads")
        logAI("AI")
        logAuth("Auth")
        dprint("Debug print")
        
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Measurement Tests
    
    func testMeasureBlock() {
        let result = MCLogger.shared.measure("Test operation") {
            // Simulate some work
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            return sum
        }
        
        XCTAssertEqual(result, 499500)
    }
    
    func testMeasureAsyncBlock() async {
        let result = await MCLogger.shared.measureAsync("Test async operation") {
            // Simulate async work
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return 42
        }
        
        XCTAssertEqual(result, 42)
    }
}
