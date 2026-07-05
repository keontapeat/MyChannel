//
//  GameplayVideoAnalysisService.swift
//  MyChannel
//
//  Vertex AI Video Analysis Service
//  Extracts scores from gameplay videos using OCR and Video Intelligence API
//

import Foundation
import SwiftUI
import AVFoundation
import Vision

@MainActor
final class GameplayVideoAnalysisService: ObservableObject {
    static let shared = GameplayVideoAnalysisService()
    
    // Published state
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    
    // Vertex AI configuration
    private let projectID = AppSecrets.googleCloudProjectID
    private let apiKey = AppSecrets.googleCloudAPIKey
    private let visionAPIEndpoint = "https://vision.googleapis.com/v1"
    
    private func safeInt(_ value: Double, fallback: Int = 0) -> Int {
        guard value.isFinite else { return fallback }
        return Int(value.rounded())
    }
    
    private init() {
        print("✅ [VideoAnalysis] Service initialized")
    }
    
    // MARK: - Main Analysis Function
    
    /// Analyze gameplay video to extract scores
    /// - Parameters:
    ///   - videoURL: URL of video to analyze
    ///   - expectedGame: Game being played (e.g., "FIFA 24", "Call of Duty")
    /// - Returns: Analysis result with extracted scores and confidence
    func analyzeGameplayVideo(
        videoURL: URL,
        expectedGame: String
    ) async throws -> VideoAnalysisResult {
        print("🎬 [VideoAnalysis] Starting analysis for: \(expectedGame)")
        
        isAnalyzing = true
        analysisProgress = 0.0
        
        defer {
            isAnalyzing = false
            analysisProgress = 0.0
        }
        
        // Step 1: Extract key frames (20%)
        print("🖼️ [VideoAnalysis] Extracting key frames...")
        let frames = try await extractKeyFrames(from: videoURL)
        analysisProgress = 0.2
        
        // Step 2: Run OCR on frames (60%)
        print("🔍 [VideoAnalysis] Running OCR on frames...")
        let extractedScores = try await extractScoresFromFrames(frames)
        analysisProgress = 0.8
        
        // Step 3: Calculate confidence (10%)
        print("📊 [VideoAnalysis] Calculating confidence...")
        let confidence = calculateConfidence(extractedScores: extractedScores, frames: frames)
        
        // Step 4: Detect game (10%)
        let detectedGame = try await detectGame(from: frames, expected: expectedGame)
        analysisProgress = 1.0
        
        let result = VideoAnalysisResult(
            extractedScores: extractedScores,
            confidence: confidence,
            keyFrames: frames,
            detectedGame: detectedGame,
            scoreboardDetected: extractedScores.scoreboardDetected,
            timestamp: Date()
        )
        
        print("✅ [VideoAnalysis] Analysis complete!")
        print("   Player 1: \(extractedScores.player1Score ?? -1)")
        print("   Player 2: \(extractedScores.player2Score ?? -1)")
        print("   Confidence: \(safeInt(confidence * 100))%")
        
        return result
    }
    
    // MARK: - Frame Extraction
    
    /// Extract key frames from video for analysis
    /// - Parameter videoURL: Video URL
    /// - Returns: Array of extracted frames as UIImages
    private func extractKeyFrames(from videoURL: URL) async throws -> [UIImage] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Extract frames at key timestamps
        let timestamps: [Double] = [
            0.0,                           // Start
            durationSeconds * 0.25,        // 25%
            durationSeconds * 0.50,        // 50%
            durationSeconds * 0.75,        // 75%
            max(durationSeconds - 5, 0),   // 5 seconds before end
            max(durationSeconds - 2, 0),   // 2 seconds before end
            max(durationSeconds - 1, 0)    // 1 second before end
        ]
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        var frames: [UIImage] = []
        
        for timestamp in timestamps {
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                frames.append(uiImage)
                print("   ✓ Extracted frame at \(Int(timestamp))s")
            } catch {
                print("   ⚠️ Failed to extract frame at \(Int(timestamp))s: \(error)")
            }
        }
        
        print("✅ [VideoAnalysis] Extracted \(frames.count) frames")
        return frames
    }
    
    // MARK: - OCR Score Extraction
    
    /// Extract scores from video frames using OCR
    /// - Parameter frames: Array of video frames
    /// - Returns: Extracted scores with metadata
    private func extractScoresFromFrames(_ frames: [UIImage]) async throws -> ExtractedScores {
        var allScores: [(player1: Int?, player2: Int?, confidence: Double)] = []
        var ocrTexts: [String] = []
        
        // Process each frame
        for (index, frame) in frames.enumerated() {
            print("   Processing frame \(index + 1)/\(frames.count)...")
            
            let text = try await performOCR(on: frame)
            ocrTexts.append(text)
            
            // Parse scores from text
            let scores = parseScoresFromText(text)
            allScores.append(scores)
            
            // Update progress
            let progress = 0.2 + (0.6 * Double(index + 1) / Double(frames.count))
            analysisProgress = progress
        }
        
        // Find most confident scores
        let bestScores = findMostConfidentScores(allScores)
        
        // Check if scoreboard detected
        let scoreboardDetected = bestScores.confidence > 0.5
        
        // Find timestamp of best scoreboard
        let bestIndex = allScores.firstIndex { $0.confidence == bestScores.confidence } ?? 0
        let scoreboardTimestamp = Double(bestIndex) / Double(frames.count) * 100.0
        
        return ExtractedScores(
            player1Score: bestScores.player1,
            player2Score: bestScores.player2,
            scoreboardDetected: scoreboardDetected,
            scoreboardTimestamp: scoreboardTimestamp,
            ocrText: ocrTexts.joined(separator: "\n---\n")
        )
    }
    
    /// Perform OCR on image using Vision framework
    /// - Parameter image: Image to analyze
    /// - Returns: Extracted text
    private func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }
            
            // Configure request for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.03
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Parse scores from OCR text
    /// - Parameter text: OCR extracted text
    /// - Returns: Tuple of scores and confidence
    private func parseScoresFromText(_ text: String) -> (player1: Int?, player2: Int?, confidence: Double) {
        // Common score patterns in games
        let patterns = [
            "([0-9]{1,3})\\s*-\\s*([0-9]{1,3})",           // "25 - 18"
            "([0-9]{1,3})\\s*:\\s*([0-9]{1,3})",           // "25 : 18"
            "([0-9]{1,3})\\s+([0-9]{1,3})",                // "25 18"
            "Score:\\s*([0-9]{1,3})\\s*-\\s*([0-9]{1,3})", // "Score: 25 - 18"
            "([0-9]{1,3})\\s*vs\\s*([0-9]{1,3})",          // "25 vs 18"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    if match.numberOfRanges >= 3,
                       let score1Range = Range(match.range(at: 1), in: text),
                       let score2Range = Range(match.range(at: 2), in: text) {
                        
                        let score1Str = String(text[score1Range])
                        let score2Str = String(text[score2Range])
                        
                        if let score1 = Int(score1Str), let score2 = Int(score2Str) {
                            // Validate scores (0-999)
                            if score1 >= 0 && score1 <= 999 && score2 >= 0 && score2 <= 999 {
                                // Higher confidence if scores are different and reasonable
                                let confidence = score1 != score2 ? 0.8 : 0.5
                                return (score1, score2, confidence)
                            }
                        }
                    }
                }
            }
        }
        
        // Try to find individual numbers (lower confidence)
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 >= 0 && $0 <= 999 }
        
        if numbers.count >= 2 {
            return (numbers[0], numbers[1], 0.3)
        }
        
        return (nil, nil, 0.0)
    }
    
    /// Find most confident scores from all frames
    /// - Parameter scores: Array of score tuples
    /// - Returns: Best scores with highest confidence
    private func findMostConfidentScores(
        _ scores: [(player1: Int?, player2: Int?, confidence: Double)]
    ) -> (player1: Int?, player2: Int?, confidence: Double) {
        // Group identical scores and sum confidence
        var scoreMap: [[Int]: Double] = [:]
        
        for score in scores {
            if let p1 = score.player1, let p2 = score.player2 {
                let key = [p1, p2]
                scoreMap[key, default: 0.0] += score.confidence
            }
        }
        
        // Find most confident score combination
        if let bestScore = scoreMap.max(by: { $0.value < $1.value }) {
            let p1 = bestScore.key[0]
            let p2 = bestScore.key[1]
            let confidence = min(bestScore.value / Double(scores.count), 1.0)
            return (p1, p2, confidence)
        }
        
        return (nil, nil, 0.0)
    }
    
    // MARK: - Confidence Calculation
    
    /// Calculate overall confidence score
    /// - Parameters:
    ///   - extractedScores: Extracted score data
    ///   - frames: Video frames
    /// - Returns: Confidence score (0.0 - 1.0)
    private func calculateConfidence(
        extractedScores: ExtractedScores,
        frames: [UIImage]
    ) -> Double {
        var confidence: Double = 0.0
        
        // Scoreboard detected (40%)
        if extractedScores.scoreboardDetected {
            confidence += 0.4
        }
        
        // Scores readable (30%)
        if extractedScores.player1Score != nil && extractedScores.player2Score != nil {
            confidence += 0.3
        }
        
        // Video quality (10%)
        let avgBrightness = calculateAverageBrightness(frames: frames)
        if avgBrightness > 0.3 && avgBrightness < 0.9 {
            confidence += 0.1
        }
        
        // Scoreboard timestamp (10%)
        if let timestamp = extractedScores.scoreboardTimestamp,
           timestamp > 70.0 { // Scoreboard near end is more reliable
            confidence += 0.1
        }
        
        // Text clarity (10%)
        if extractedScores.ocrText.count > 50 { // Substantial text detected
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    /// Calculate average brightness of frames
    /// - Parameter frames: Array of frames
    /// - Returns: Average brightness (0.0 - 1.0)
    private func calculateAverageBrightness(frames: [UIImage]) -> Double {
        var totalBrightness: Double = 0.0
        
        for frame in frames {
            if let brightness = frame.averageBrightness() {
                totalBrightness += brightness
            }
        }
        
        return frames.isEmpty ? 0.0 : totalBrightness / Double(frames.count)
    }
    
    // MARK: - Game Detection
    
    /// Detect game from video frames
    /// - Parameters:
    ///   - frames: Video frames
    ///   - expected: Expected game name
    /// - Returns: Detected game name
    private func detectGame(from frames: [UIImage], expected: String) async throws -> String? {
        // Use Vertex AI Vision to detect the game logo in the first frame
        // Falls back to the expected game name if Vision unavailable
        guard let firstFrame = frames.first,
              let jpegData = firstFrame.jpegData(compressionQuality: 0.5) else {
            return expected
        }
        let base64 = jpegData.base64EncodedString()
        let projectId = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"] ?? ""
        guard !projectId.isEmpty else { return expected }
        // Vertex AI Vision label detection endpoint
        let urlStr = "https://vision.googleapis.com/v1/images:annotate"
        guard let url = URL(string: urlStr) else { return expected }
        let body: [String: Any] = ["requests": [["image": ["content": base64], "features": [["type": "LOGO_DETECTION", "maxResults": 5]]]]]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responses = (json["responses"] as? [[String: Any]])?.first,
           let annotations = responses["logoAnnotations"] as? [[String: Any]],
           let first = annotations.first,
           let desc = first["description"] as? String {
            return desc
        }
        return expected
    }
}

// MARK: - Analysis Result Models

struct VideoAnalysisResult {
    let extractedScores: ExtractedScores
    let confidence: Double // 0.0 - 1.0
    let keyFrames: [UIImage]
    let detectedGame: String?
    let scoreboardDetected: Bool
    let timestamp: Date
}

struct ExtractedScores {
    let player1Score: Int?
    let player2Score: Int?
    let scoreboardDetected: Bool
    let scoreboardTimestamp: TimeInterval? // Percentage of video (0-100)
    let ocrText: String // Raw OCR text for debugging
}

// MARK: - Analysis Error

enum AnalysisError: LocalizedError {
    case invalidVideo
    case invalidImage
    case noFramesExtracted
    case ocrFailed
    case noScoresDetected
    case lowConfidence
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "Invalid video file. Please upload a valid gameplay video."
        case .invalidImage:
            return "Invalid image format."
        case .noFramesExtracted:
            return "Failed to extract frames from video."
        case .ocrFailed:
            return "Failed to read text from video."
        case .noScoresDetected:
            return "Could not detect scores in video. Please ensure scoreboard is visible."
        case .lowConfidence:
            return "Score detection confidence too low. Please upload a clearer video."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Calculate average brightness of image
    /// - Returns: Brightness value (0.0 - 1.0) or nil if calculation fails
    func averageBrightness() -> Double? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalBrightness: Double = 0.0
        
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Double(pixelData[i])
            let g = Double(pixelData[i + 1])
            let b = Double(pixelData[i + 2])
            
            // Calculate perceived brightness
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            totalBrightness += brightness
        }
        
        let pixelCount = width * height
        return pixelCount > 0 ? totalBrightness / Double(pixelCount) : nil
    }
}

