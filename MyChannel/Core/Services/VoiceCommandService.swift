//
//  VoiceCommandService.swift
//  MyChannel
//
//  Voice Commands - Siri/voice control for common actions
//

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class VoiceCommandService: ObservableObject {
    static let shared = VoiceCommandService()
    
    @Published private(set) var isListening = false
    @Published private(set) var recognizedCommand: String = ""
    @Published private(set) var commandHistory: [VoiceCommand] = []
    
    struct VoiceCommand: Identifiable, Codable {
        let id: String
        let command: String
        let action: String
        let executedAt: Date
        let success: Bool
    }
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("✅ Voice commands authorized")
            case .denied, .restricted, .notDetermined:
                print("⚠️ Voice commands not authorized")
            @unknown default:
                break
            }
        }
    }
    
    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.recognizedCommand = result.bestTranscription.formattedString.lowercased()
                
                if result.isFinal {
                    Task { @MainActor in
                        await self.executeCommand(self.recognizedCommand)
                    }
                }
            }
            
            if let error = error {
                print("⚠️ Voice recognition error: \(error)")
                self.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
    
    private func executeCommand(_ command: String) async {
        var action = ""
        var success = false
        
        switch true {
        case command.contains("refresh"):
            action = "refresh_dashboard"
            // Trigger dashboard refresh
            success = true
        case command.contains("generate report"):
            action = "generate_report"
            success = true
        case command.contains("show fraud"):
            action = "show_fraud_tab"
            success = true
        case command.contains("show users"):
            action = "show_users_tab"
            success = true
        case command.contains("show revenue"):
            action = "show_revenue_tab"
            success = true
        case command.contains("show system"):
            action = "show_system_tab"
            success = true
        default:
            action = "unknown_command"
            success = false
        }
        
        let voiceCommand = VoiceCommand(
            id: UUID().uuidString,
            command: command,
            action: action,
            executedAt: Date(),
            success: success
        )
        
        commandHistory.insert(voiceCommand, at: 0)
        if commandHistory.count > 50 { commandHistory.removeLast() }
        
        // Log the command
        try? await ComplianceAuditLogService.shared.logAction(
            userId: "voice_command",
            userEmail: nil,
            action: "voice_command_executed",
            resource: "command_center",
            details: "Command: \(command), Action: \(action)",
            ipAddress: nil,
            userAgent: nil,
            severity: "info"
        )
    }
}
