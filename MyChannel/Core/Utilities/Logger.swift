//
//  Logger.swift
//  MyChannel
//
//  Production-safe logging wrapper that only logs in DEBUG builds.
//  Use this instead of print() throughout the app.
//

import Foundation
import os.log

// MARK: - 🔥 Production-Safe Logger
/// A production-safe logging wrapper that:
/// - Only logs in DEBUG builds (silent in App Store/TestFlight)
/// - Uses Apple's unified logging system (os.log) for better performance
/// - Provides categorized logging for easier debugging
/// - Supports log levels for filtering
public struct MCLogger {
    
    // MARK: - Log Levels
    public enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
        case critical = "🚨"
        case network = "🌐"
        case firebase = "🔥"
        case performance = "⚡"
        case analytics = "📊"
        case payment = "💰"
        case player = "🎬"
        case upload = "📤"
        case download = "📥"
        case auth = "🔐"
        case ai = "🤖"
        case ads = "📺"
    }
    
    // MARK: - Categories
    public enum Category: String {
        case general = "General"
        case network = "Network"
        case firebase = "Firebase"
        case player = "Player"
        case upload = "Upload"
        case download = "Download"
        case auth = "Auth"
        case ads = "Ads"
        case analytics = "Analytics"
        case performance = "Performance"
        case ai = "AI"
        case payment = "Payment"
        case ui = "UI"
        case storage = "Storage"
        case cache = "Cache"
    }
    
    // MARK: - Singleton
    public static let shared = MCLogger()
    
    // MARK: - Private Properties
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.mychannel.app"
    
    private init() {}
    
    // MARK: - Private OS Loggers (lazy initialized)
    private func osLogger(for category: Category) -> OSLog {
        OSLog(subsystem: subsystem, category: category.rawValue)
    }
    
    // MARK: - Public Logging Methods
    
    /// Log a debug message (only in DEBUG builds)
    public func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message
    public func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log a success message
    public func success(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    public func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    public func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log a critical error message
    public func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    /// Log a network message
    public func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .network, category: .network, file: file, function: function, line: line)
    }
    
    /// Log a Firebase message
    public func firebase(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .firebase, category: .firebase, file: file, function: function, line: line)
    }
    
    /// Log a performance message
    public func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .performance, category: .performance, file: file, function: function, line: line)
    }
    
    /// Log a payment/monetization message
    public func payment(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .payment, category: .payment, file: file, function: function, line: line)
    }
    
    /// Log a player message
    public func player(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .player, category: .player, file: file, function: function, line: line)
    }
    
    /// Log an ads message
    public func ads(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .ads, category: .ads, file: file, function: function, line: line)
    }
    
    /// Log an AI message
    public func ai(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .ai, category: .ai, file: file, function: function, line: line)
    }
    
    /// Log an auth message
    public func auth(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .auth, category: .auth, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging Method
    private func log(_ message: String, level: Level, category: Category, file: String, function: String, line: Int) {
        #if DEBUG
        // Get just the filename without path
        let filename = (file as NSString).lastPathComponent
        
        // Format: [Category] emoji Message (File:Line)
        let formattedMessage = "[\(category.rawValue)] \(level.rawValue) \(message) (\(filename):\(line))"
        
        // Print to console in debug
        print(formattedMessage)
        
        // Also log to OSLog for Console.app viewing
        let osLogType: OSLogType
        switch level {
        case .debug, .info, .success:
            osLogType = .debug
        case .warning:
            osLogType = .info
        case .error:
            osLogType = .error
        case .critical:
            osLogType = .fault
        default:
            osLogType = .default
        }
        
        os_log("%{public}@", log: osLogger(for: category), type: osLogType, formattedMessage)
        #endif
    }
}

// MARK: - Global Convenience Functions
/// Use these for quick logging throughout the app

/// Debug log - only shows in DEBUG builds
public func logDebug(_ message: String, category: MCLogger.Category = .general) {
    MCLogger.shared.debug(message, category: category)
}

/// Info log
public func logInfo(_ message: String, category: MCLogger.Category = .general) {
    MCLogger.shared.info(message, category: category)
}

/// Success log
public func logSuccess(_ message: String, category: MCLogger.Category = .general) {
    MCLogger.shared.success(message, category: category)
}

/// Warning log
public func logWarning(_ message: String, category: MCLogger.Category = .general) {
    MCLogger.shared.warning(message, category: category)
}

/// Error log
public func logError(_ message: String, category: MCLogger.Category = .general) {
    MCLogger.shared.error(message, category: category)
}

/// Network log
public func logNetwork(_ message: String) {
    MCLogger.shared.network(message)
}

/// Firebase log
public func logFirebase(_ message: String) {
    MCLogger.shared.firebase(message)
}

/// Performance log
public func logPerformance(_ message: String) {
    MCLogger.shared.performance(message)
}

/// Payment/Monetization log
public func logPayment(_ message: String) {
    MCLogger.shared.payment(message)
}

/// Player log
public func logPlayer(_ message: String) {
    MCLogger.shared.player(message)
}

/// Ads log
public func logAds(_ message: String) {
    MCLogger.shared.ads(message)
}

/// AI log
public func logAI(_ message: String) {
    MCLogger.shared.ai(message)
}

/// Auth log
public func logAuth(_ message: String) {
    MCLogger.shared.auth(message)
}

// MARK: - Debug-only print replacement
/// Drop-in replacement for print() that only works in DEBUG builds
/// Usage: debugPrint("message") or dprint("message")
public func dprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}

// MARK: - Performance Measurement
extension MCLogger {
    /// Measure execution time of a block
    public func measure<T>(_ label: String, block: () throws -> T) rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        performance("\(label): \(String(format: "%.2f", elapsed))ms")
        return result
        #else
        return try block()
        #endif
    }
    
    /// Measure async execution time
    public func measureAsync<T>(_ label: String, block: () async throws -> T) async rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        performance("\(label): \(String(format: "%.2f", elapsed))ms")
        return result
        #else
        return try await block()
        #endif
    }
}
