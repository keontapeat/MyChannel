//
//  VoiceEffectsEngine.swift
//  MyChannel
//
//  🎤 VOICE EFFECTS ENGINE
//  Real-time voice modulation and audio effects (like TikTok)
//

import SwiftUI
import AVFoundation
import Accelerate

@MainActor
class VoiceEffectsEngine: ObservableObject {
    
    // MARK: - Published State
    @Published var selectedEffect: VoiceEffect = .none
    @Published var isProcessing = false
    @Published var volume: Float = 1.0
    @Published var pitch: Float = 0.0 // -12 to +12 semitones
    @Published var speed: Float = 1.0 // 0.5x to 2x
    @Published var reverb: Float = 0.0 // 0 to 100%
    @Published var echo: Float = 0.0 // 0 to 100%
    
    // Audio engine
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var pitchEffect: AVAudioUnitTimePitch?
    private var reverbEffect: AVAudioUnitReverb?
    private var distortionEffect: AVAudioUnitDistortion?
    private var delayEffect: AVAudioUnitDelay?
    
    // Audio file
    private var audioFile: AVAudioFile?
    
    // Available voice effects
    let availableEffects: [VoiceEffectOption] = [
        VoiceEffectOption(effect: .none, name: "Original", icon: "waveform"),
        VoiceEffectOption(effect: .chipmunk, name: "Chipmunk", icon: "hare"),
        VoiceEffectOption(effect: .deepVoice, name: "Deep", icon: "person.fill"),
        VoiceEffectOption(effect: .robot, name: "Robot", icon: "cpu"),
        VoiceEffectOption(effect: .echo, name: "Echo", icon: "speaker.wave.2"),
        VoiceEffectOption(effect: .reverb, name: "Reverb", icon: "building.2"),
        VoiceEffectOption(effect: .megaphone, name: "Megaphone", icon: "megaphone"),
        VoiceEffectOption(effect: .telephone, name: "Telephone", icon: "phone"),
        VoiceEffectOption(effect: .underwater, name: "Underwater", icon: "drop.fill"),
        VoiceEffectOption(effect: .alien, name: "Alien", icon: "star.fill")
    ]
    
    // MARK: - Initialization
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        pitchEffect = AVAudioUnitTimePitch()
        reverbEffect = AVAudioUnitReverb()
        distortionEffect = AVAudioUnitDistortion()
        delayEffect = AVAudioUnitDelay()
        
        guard let engine = audioEngine,
              let player = audioPlayerNode else { return }
        
        // Attach nodes
        engine.attach(player)
        
        if let pitch = pitchEffect {
            engine.attach(pitch)
        }
        
        if let reverb = reverbEffect {
            engine.attach(reverb)
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 0
        }
        
        if let distortion = distortionEffect {
            engine.attach(distortion)
            distortion.wetDryMix = 0
        }
        
        if let delay = delayEffect {
            engine.attach(delay)
            delay.wetDryMix = 0
        }
        
        // Connect nodes
        connectNodes()
    }
    
    private func connectNodes() {
        guard let engine = audioEngine,
              let player = audioPlayerNode,
              let pitch = pitchEffect,
              let reverb = reverbEffect,
              let distortion = distortionEffect,
              let delay = delayEffect else { return }
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        // Chain: Player -> Pitch -> Reverb -> Distortion -> Delay -> Output
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: reverb, format: format)
        engine.connect(reverb, to: distortion, format: format)
        engine.connect(distortion, to: delay, format: format)
        engine.connect(delay, to: engine.mainMixerNode, format: format)
    }
    
    // MARK: - Effect Application
    func applyEffect(_ effect: VoiceEffect, to audioURL: URL) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        // Load audio file
        audioFile = try AVAudioFile(forReading: audioURL)
        
        // Configure effect
        configureEffect(effect)
        
        // Process audio
        let outputURL = try await processAudio()
        
        return outputURL
    }
    
    func applyEffectRealtime(_ effect: VoiceEffect) {
        selectedEffect = effect
        configureEffect(effect)
        HapticManager.shared.impact(style: .medium)
    }
    
    private func configureEffect(_ effect: VoiceEffect) {
        switch effect {
        case .none:
            resetEffects()
            
        case .chipmunk:
            pitchEffect?.pitch = 800 // High pitch
            pitchEffect?.rate = 1.5
            
        case .deepVoice:
            pitchEffect?.pitch = -800 // Low pitch
            pitchEffect?.rate = 0.8
            
        case .robot:
            distortionEffect?.loadFactoryPreset(.multiDecimated1)
            distortionEffect?.wetDryMix = 50
            pitchEffect?.pitch = -200
            
        case .echo:
            delayEffect?.delayTime = 0.3
            delayEffect?.feedback = 50
            delayEffect?.wetDryMix = 50
            
        case .reverb:
            reverbEffect?.loadFactoryPreset(.cathedral)
            reverbEffect?.wetDryMix = 50
            
        case .megaphone:
            distortionEffect?.loadFactoryPreset(.multiDecimated2)
            distortionEffect?.wetDryMix = 40
            pitchEffect?.pitch = 100
            
        case .telephone:
            distortionEffect?.loadFactoryPreset(.multiDecimated3)
            distortionEffect?.wetDryMix = 60
            pitchEffect?.pitch = 200
            
        case .underwater:
            reverbEffect?.loadFactoryPreset(.largeHall)
            reverbEffect?.wetDryMix = 70
            pitchEffect?.pitch = -300
            pitchEffect?.rate = 0.7
            
        case .alien:
            pitchEffect?.pitch = 1200
            pitchEffect?.rate = 1.3
            reverbEffect?.wetDryMix = 30
            distortionEffect?.wetDryMix = 20
        }
    }
    
    private func resetEffects() {
        pitchEffect?.pitch = 0
        pitchEffect?.rate = 1.0
        reverbEffect?.wetDryMix = 0
        distortionEffect?.wetDryMix = 0
        delayEffect?.wetDryMix = 0
    }
    
    // MARK: - Audio Processing
    private func processAudio() async throws -> URL {
        guard let audioFile = audioFile,
              let engine = audioEngine,
              let player = audioPlayerNode else {
            throw VoiceEffectError.processingFailed
        }
        
        // Output file
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        // Output settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: settings
        )
        
        // Start engine
        try engine.start()
        
        // Schedule audio
        try await player.scheduleFile(audioFile, at: nil)
        
        // Install tap to capture output
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: engine.mainMixerNode.outputFormat(forBus: 0)
        ) { buffer, _ in
            do {
                try outputFile.write(from: buffer)
            } catch {
                print("🚨 Error writing buffer: \(error)")
            }
        }
        
        // Play
        player.play()
        
        // Wait for completion
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        // Stop
        player.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        
        return outputURL
    }
    
    // MARK: - Manual Controls
    func updatePitch(_ newPitch: Float) {
        pitch = newPitch
        pitchEffect?.pitch = newPitch * 100 // Convert to cents
    }
    
    func updateSpeed(_ newSpeed: Float) {
        speed = newSpeed
        pitchEffect?.rate = newSpeed
    }
    
    func updateReverb(_ newReverb: Float) {
        reverb = newReverb
        reverbEffect?.wetDryMix = newReverb
    }
    
    func updateEcho(_ newEcho: Float) {
        echo = newEcho
        delayEffect?.wetDryMix = newEcho
    }
    
    func updateVolume(_ newVolume: Float) {
        volume = newVolume
        audioEngine?.mainMixerNode.outputVolume = newVolume
    }
    
    // MARK: - Real-time Recording with Effects
    func startRecordingWithEffects() throws {
        guard let engine = audioEngine else {
            throw VoiceEffectError.engineNotReady
        }
        
        // Setup microphone input
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            // Process buffer with effects
            self?.processRealtimeBuffer(buffer, time: time)
        }
        
        try engine.start()
    }
    
    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
    }
    
    private func processRealtimeBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Real-time processing
        // Buffer is automatically processed through effect chain
    }
    
    deinit {
        audioEngine?.stop()
    }
}

// MARK: - Voice Effect Types
enum VoiceEffect: String, Codable, CaseIterable {
    case none = "None"
    case chipmunk = "Chipmunk"
    case deepVoice = "Deep Voice"
    case robot = "Robot"
    case echo = "Echo"
    case reverb = "Reverb"
    case megaphone = "Megaphone"
    case telephone = "Telephone"
    case underwater = "Underwater"
    case alien = "Alien"
}

struct VoiceEffectOption: Identifiable {
    let id = UUID()
    let effect: VoiceEffect
    let name: String
    let icon: String
}

// MARK: - Errors
enum VoiceEffectError: LocalizedError {
    case engineNotReady
    case processingFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .engineNotReady: return "Audio engine not ready"
        case .processingFailed: return "Audio processing failed"
        case .fileNotFound: return "Audio file not found"
        }
    }
}

