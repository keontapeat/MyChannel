import Foundation

/// Phase 39: Interactive Transcription View
/// Parses VTT/SRT subtitles into a clickable transcript scroll view array.
final class TranscriptParser {
    static let shared = TranscriptParser()
    
    private init() {}
    
    func parseVTT(_ vttString: String) -> [TranscriptLine] {
        var transcriptLines: [TranscriptLine] = []
        let lines = vttString.components(separatedBy: .newlines)
        
        var currentStartTime: Double = 0
        var currentEndTime: Double = 0
        var currentText = ""
        
        // Simple VTT state machine
        var isReadingTime = false
        var isReadingText = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                // End of block
                if isReadingText && !currentText.isEmpty {
                    transcriptLines.append(TranscriptLine(startTime: currentStartTime, endTime: currentEndTime, text: currentText))
                    currentText = ""
                }
                isReadingTime = false
                isReadingText = false
                continue
            }
            
            if trimmed == "WEBVTT" {
                continue
            }
            
            if trimmed.contains("-->") {
                let times = trimmed.components(separatedBy: "-->")
                if times.count == 2,
                   let start = parseTime(times[0].trimmingCharacters(in: .whitespaces)),
                   let end = parseTime(times[1].trimmingCharacters(in: .whitespaces)) {
                    currentStartTime = start
                    currentEndTime = end
                    isReadingTime = false
                    isReadingText = true
                }
            } else if isReadingText {
                if currentText.isEmpty {
                    currentText = trimmed
                } else {
                    currentText += " " + trimmed
                }
            }
        }
        
        // Catch final block
        if isReadingText && !currentText.isEmpty {
            transcriptLines.append(TranscriptLine(startTime: currentStartTime, endTime: currentEndTime, text: currentText))
        }
        
        return transcriptLines
    }
    
    private func parseTime(_ timeStr: String) -> Double? {
        // "00:00:15.000" or "00:15.000"
        let parts = timeStr.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }
        
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2]) ?? 0
            return (h * 3600) + (m * 60) + s
        } else {
            let m = Double(parts[0]) ?? 0
            let s = Double(parts[1]) ?? 0
            return (m * 60) + s
        }
    }
}

struct TranscriptLine: Identifiable, Hashable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    let text: String
}
