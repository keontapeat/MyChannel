import Foundation
import Accelerate
import AVFoundation

/// Phase 44: Audio Waveform Generator Engine
/// Utilizes Accelerate (vDSP) to extract audio waveforms extremely fast.
final class WaveformGenerator {
    static let shared = WaveformGenerator()
    
    private init() {}
    
    /// Generates normalized waveform samples from an audio file.
    func generateWaveform(from url: URL, targetSamples: Int) async throws -> [Float] {
        return try await Task.detached {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw WaveformError.bufferCreationFailed
            }
            
            try file.read(into: buffer)
            
            guard let floatChannelData = buffer.floatChannelData else {
                throw WaveformError.channelDataMissing
            }
            
            let channelCount = Int(format.channelCount)
            let length = Int(buffer.frameLength)
            let samplesPerBin = length / targetSamples
            
            var waveform: [Float] = []
            waveform.reserveCapacity(targetSamples)
            
            // We use vDSP to calculate the RMS (Root Mean Square) for each bin
            for bin in 0..<targetSamples {
                let start = bin * samplesPerBin
                let end = min(start + samplesPerBin, length)
                let count = end - start
                
                var rms: Float = 0
                for channel in 0..<channelCount {
                    let channelData = floatChannelData[channel]
                    let binData = channelData.advanced(by: start)
                    
                    var channelRMS: Float = 0
                    // vDSP RMS calculation: mean square then sqrt
                    vDSP_rmsqv(binData, 1, &channelRMS, vDSP_Length(count))
                    
                    rms += channelRMS
                }
                
                // Average across channels
                rms /= Float(channelCount)
                waveform.append(rms)
            }
            
            // Normalize the waveform to 0.0 - 1.0
            guard let maxVal = waveform.max(), maxVal > 0 else { return waveform }
            
            var normalized = [Float](repeating: 0, count: targetSamples)
            var scale = 1.0 / maxVal
            vDSP_vsmul(waveform, 1, &scale, &normalized, 1, vDSP_Length(targetSamples))
            
            return normalized
        }.value
    }
    
    enum WaveformError: Error {
        case bufferCreationFailed
        case channelDataMissing
    }
}
