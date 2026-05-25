//
//  CCVoiceAssistantService.swift
//  MyChannel
//
//  Phase 900: Command Center Voice & AI Assistant
//  Voice commands, AI copilot (Gemini), natural language queries, conversational incidents
//

import Foundation
import Combine
import FirebaseFirestore
import Speech

@MainActor
final class CCVoiceAssistantService: ObservableObject {
    static let shared = CCVoiceAssistantService()

    // MARK: - Domain Models

    struct VoiceCommand: Identifiable, Codable {
        let id: String
        let phrase: String
        let intent: CommandIntent
        let parameters: [String: String]
        let executedAt: Date
        let success: Bool
    }

    enum CommandIntent: String, Codable, CaseIterable {
        case showFraudAlerts = "SHOW_FRAUD_ALERTS"
        case approveContent = "APPROVE_CONTENT"
        case showRevenue = "SHOW_REVENUE"
        case showLiveStreams = "SHOW_LIVE_STREAMS"
        case showSystemHealth = "SHOW_SYSTEM_HEALTH"
        case escalateIncident = "ESCALATE_INCIDENT"
        case enableMaintenance = "ENABLE_MAINTENANCE"
        case disableMaintenance = "DISABLE_MAINTENANCE"
        case showCreatorHealth = "SHOW_CREATOR_HEALTH"
        case generateBriefing = "GENERATE_BRIEFING"
        case unknown = "UNKNOWN"
    }

    struct AIConversation: Identifiable, Codable {
        let id: String
        let role: String
        let content: String
        let timestamp: Date
    }

    struct EmergencyProtocol: Identifiable, Codable {
        let id: String
        let name: String
        let triggerPhrase: String
        let actions: [String]
        let confirmationRequired: Bool
    }

    // MARK: - Published State

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var lastCommand: VoiceCommand?
    @Published private(set) var commandHistory: [VoiceCommand] = []
    @Published private(set) var conversation: [AIConversation] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var aiResponse: String?
    @Published private(set) var emergencyProtocols: [EmergencyProtocol] = []
    @Published private(set) var isVoiceAvailable = false

    private var db = Firestore.firestore()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private init() {
        checkAvailability()
        Task { await loadProtocols(); await loadHistory() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://cc-voice-assistant-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCCVoiceAssistant else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Availability

    private func checkAvailability() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isVoiceAvailable = status == .authorized
            }
        }
    }

    // MARK: - Load

    func loadProtocols() async {
        let snap = try? await db.collection("ccEmergencyProtocols").getDocuments()
        emergencyProtocols = snap?.documents.compactMap { doc in
            let d = doc.data()
            return EmergencyProtocol(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                triggerPhrase: d["triggerPhrase"] as? String ?? "",
                actions: d["actions"] as? [String] ?? [],
                confirmationRequired: d["confirmationRequired"] as? Bool ?? true
            )
        } ?? []
    }

    func loadHistory() async {
        let snap = try? await db.collection("ccVoiceCommands")
            .order(by: "executedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        commandHistory = snap?.documents.compactMap { doc in
            let d = doc.data()
            guard let intent = CommandIntent(rawValue: d["intent"] as? String ?? "") else { return nil }
            return VoiceCommand(
                id: doc.documentID,
                phrase: d["phrase"] as? String ?? "",
                intent: intent,
                parameters: d["parameters"] as? [String: String] ?? [:],
                executedAt: (d["executedAt"] as? Timestamp)?.dateValue() ?? Date(),
                success: d["success"] as? Bool ?? false
            )
        } ?? []
    }

    // MARK: - Voice Recognition

    func startListening() {
        guard isVoiceAvailable, !isListening else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        let node = audioEngine.inputNode
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.isListening = false
                        await self.processVoiceCommand(self.transcript)
                    }
                }
                if error != nil {
                    self.isListening = false
                }
            }
        }

        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
        transcript = ""
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }

    // MARK: - Command Processing

    func processVoiceCommand(_ text: String) async {
        guard AppConfig.Features.enableCCVoiceAssistant else { return }
        isProcessing = true
        defer { isProcessing = false }

        // Match intent from voice text
        let intent = matchIntent(text)
        let params = extractParameters(text, intent: intent)

        let command = VoiceCommand(
            id: UUID().uuidString,
            phrase: text,
            intent: intent,
            parameters: params,
            executedAt: Date(),
            success: true
        )
        lastCommand = command
        commandHistory.insert(command, at: 0)

        // Check emergency protocols
        for protocol_ in emergencyProtocols where text.lowercased().contains(protocol_.triggerPhrase.lowercased()) {
            await executeEmergencyProtocol(protocol_)
            return
        }

        // Execute via Cloud Run
        _ = await callCloudRun(endpoint: "command", body: [
            "phrase": text, "intent": intent.rawValue, "parameters": params
        ])

        // Log
        try? await db.collection("ccVoiceCommands").addDocument(data: [
            "phrase": text, "intent": intent.rawValue,
            "parameters": params, "executedAt": Timestamp(date: Date()), "success": true
        ])
    }

    // MARK: - AI Conversation

    func askAI(_ question: String) async -> String {
        guard AppConfig.Features.enableCCVoiceAssistant else { return "Voice assistant disabled" }
        isProcessing = true
        defer { isProcessing = false }

        conversation.append(AIConversation(id: UUID().uuidString, role: "user", content: question, timestamp: Date()))

        // Call Gemini for conversational response
        let response = await callGemini(prompt: buildAIPrompt(question: question))
        let answer = response ?? "I'm unable to process that right now. Please try again."

        conversation.append(AIConversation(id: UUID().uuidString, role: "assistant", content: answer, timestamp: Date()))
        aiResponse = answer
        return answer
    }

    // MARK: - Emergency Protocol

    private func executeEmergencyProtocol(_ protocol_: EmergencyProtocol) async {
        for action in protocol_.actions {
            _ = await callCloudRun(endpoint: "emergency", body: ["action": action])
        }
        conversation.append(AIConversation(id: UUID().uuidString, role: "system", content: "Emergency protocol '\(protocol_.name)' activated: \(protocol_.actions.joined(separator: ", "))", timestamp: Date()))
    }

    // MARK: - Intent Matching

    private func matchIntent(_ text: String) -> CommandIntent {
        let lower = text.lowercased()
        if lower.contains("fraud") || lower.contains("scam") { return .showFraudAlerts }
        if lower.contains("approve") && lower.contains("content") { return .approveContent }
        if lower.contains("revenue") || lower.contains("money") || lower.contains("earnings") { return .showRevenue }
        if lower.contains("live") || lower.contains("stream") { return .showLiveStreams }
        if lower.contains("system") || lower.contains("health") || lower.contains("infra") { return .showSystemHealth }
        if lower.contains("escalate") || lower.contains("incident") { return .escalateIncident }
        if lower.contains("maintenance") && (lower.contains("enable") || lower.contains("turn on")) { return .enableMaintenance }
        if lower.contains("maintenance") && (lower.contains("disable") || lower.contains("turn off")) { return .disableMaintenance }
        if lower.contains("creator") { return .showCreatorHealth }
        if lower.contains("briefing") || lower.contains("summary") { return .generateBriefing }
        return .unknown
    }

    private func extractParameters(_ text: String, intent: CommandIntent) -> [String: String] {
        var params: [String: String] = [:]
        if intent == .approveContent { params["scope"] = "all_safe" }
        if intent == .showRevenue { params["period"] = "today" }
        return params
    }

    // MARK: - Gemini

    private func callGemini(prompt: String) async -> String? {
        let key = AppSecrets.googleCloudAPIKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(key)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 400, "temperature": 0.3]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    private func buildAIPrompt(question: String) -> String {
        let recentContext = conversation.suffix(6).map { "\($0.role): \($0.content)" }.joined(separator: "\n")
        return """
        You are the AI operations copilot for MyChannel's Command Center. The owner (Keonta) is asking you a question about platform operations.

        Recent conversation:
        \(recentContext)

        Current question: \(question)

        Respond concisely (2-3 sentences max). Use specific numbers if available. If you don't have current data, say so and suggest checking the relevant Command Center tab.
        """
    }
}
