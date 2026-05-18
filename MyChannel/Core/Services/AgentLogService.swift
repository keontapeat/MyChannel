import SwiftyBeaver
import Logging
import Foundation

// MARK: - Unified Agent + Platform Logger

/// Structured logging pipeline: SwiftyBeaver (console + file) backed by swift-log.
/// All 30 AGI agents, 3-Strike events, and Command Center ops log through here.
final class AgentLogService {
    static let shared = AgentLogService()

    // SwiftyBeaver destinations
    private let beaver = SwiftyBeaver.self
    // swift-log logger
    private(set) var logger: Logger

    private init() {
        // Console destination (debug only)
        let console = ConsoleDestination()
        console.minLevel = .debug
        console.format = "$DHH:mm:ss$d [$L] $N.$F:$l - $M"
        beaver.addDestination(console)

        // File destination — persisted to Documents
        let file = FileDestination()
        if let logURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("mychannel-agents.log") {
            file.logFileURL = logURL
        }
        file.minLevel = .info
        beaver.addDestination(file)

        // swift-log
        logger = Logger(label: "live.mychannel.agents")
    }

    // MARK: - Agent Events

    func agentStarted(_ name: String, agentId: String) {
        beaver.info("🚀 [\(agentId)] \(name) started")
        logger.info("agent.started", metadata: ["id": "\(agentId)", "name": "\(name)"])
    }

    func agentCompleted(_ name: String, agentId: String, latencyMs: Int, output: String) {
        beaver.info("✅ [\(agentId)] \(name) completed in \(latencyMs)ms | \(output.prefix(120))")
        logger.info("agent.completed", metadata: ["id": "\(agentId)", "latency_ms": "\(latencyMs)"])
    }

    func agentFailed(_ name: String, agentId: String, error: String) {
        beaver.error("❌ [\(agentId)] \(name) FAILED: \(error)")
        logger.error("agent.failed", metadata: ["id": "\(agentId)", "error": "\(error)"])
    }

    func agentThrottled(_ name: String, agentId: String) {
        beaver.warning("⏸ [\(agentId)] \(name) throttled")
        logger.warning("agent.throttled", metadata: ["id": "\(agentId)"])
    }

    // MARK: - Strike Events

    func strikeIssued(userId: String, strikeCount: Int, reason: String, toxicityScore: Double?) {
        let score = toxicityScore.map { String(format: "%.2f", $0) } ?? "n/a"
        beaver.warning("⚠️ [Strike] user=\(userId) strike=\(strikeCount) toxicity=\(score) reason=\(reason)")
        logger.warning("strike.issued", metadata: [
            "user_id": "\(userId)", "count": "\(strikeCount)", "toxicity": "\(score)"
        ])
    }

    func userBanned(userId: String, reason: String) {
        beaver.error("🚫 [Ban] user=\(userId) reason=\(reason)")
        logger.critical("user.banned", metadata: ["user_id": "\(userId)"])
    }

    func userWarned(userId: String, reason: String) {
        beaver.info("📋 [Warn] user=\(userId) reason=\(reason)")
        logger.info("user.warned", metadata: ["user_id": "\(userId)"])
    }

    // MARK: - Command Center Events

    func reportGenerated(type: String, rowCount: Int) {
        beaver.info("📊 [Report] type=\(type) rows=\(rowCount)")
        logger.info("report.generated", metadata: ["type": "\(type)", "rows": "\(rowCount)"])
    }

    func fraudDetected(userId: String, signal: String, confidence: Double) {
        beaver.error("🔴 [Fraud] user=\(userId) signal=\(signal) confidence=\(String(format: "%.0f%%", confidence * 100))")
        logger.critical("fraud.detected", metadata: ["user_id": "\(userId)", "signal": "\(signal)"])
    }

    // MARK: - Retrieve recent logs

    func recentLogLines(max: Int = 200) -> [String] {
        guard let logURL = FileDestination().logFileURL,
              let content = try? String(contentsOf: logURL, encoding: .utf8) else { return [] }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        return Array(lines.suffix(max))
    }
}
