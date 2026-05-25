//
//  VoiceSearchService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import AVFoundation
import Speech
import SwiftUI

// 🎤 Voice Search Service
// Handles speech-to-text for voice search functionality
@MainActor
class VoiceSearchService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // Request authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    // Start listening
    func startListening() async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw VoiceSearchError.notAuthorized
            }
        }
        
        // Cancel any ongoing recognition
        if recognitionTask != nil {
            stopListening()
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceSearchError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get audio input
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.stopListening()
            }
        }
        
        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
        transcribedText = ""
        errorMessage = nil
    }
    
    // Stop listening
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
    }
    
    deinit {
        // Note: Can't call @MainActor method directly from deinit
        // Resources will be cleaned up automatically
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension VoiceSearchService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.errorMessage = "Speech recognition is not available"
                self.stopListening()
            }
        }
    }
}

// MARK: - Errors
enum VoiceSearchError: LocalizedError {
    case notAuthorized
    case recognitionRequestFailed
    case audioEngineFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        case .audioEngineFailed:
            return "Failed to start audio engine"
        }
    }
}

