import Foundation
import AVFoundation
import CoreImage
import Metal

/// Phase 95: Metal Image Processing Pipeline
/// Applies real-time cinematic color grading to AVPlayer output using CoreImage and Metal.
final class MetalVideoCompositor: NSObject, AVVideoCompositing {
    
    // Required properties for AVVideoCompositing
    var sourcePixelBufferAttributes: [String : Any]? = [
        String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
    ]
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
    ]
    
    // CoreImage context backed by Metal
    private let renderContext: CIContext
    private let colorFilter: CIFilter
    
    override init() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.renderContext = CIContext(mtlDevice: device)
        } else {
            // Fallback to CPU if Metal isn't available (simulator sometimes)
            self.renderContext = CIContext()
        }
        
        // Example cinematic filter: "CIPhotoEffectChrome" or "CIColorControls"
        self.colorFilter = CIFilter(name: "CIColorControls")!
        self.colorFilter.setValue(1.1, forKey: kCIInputSaturationKey)
        self.colorFilter.setValue(1.05, forKey: kCIInputContrastKey)
        
        super.init()
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Handle changes in resolution if needed
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let trackID = asyncVideoCompositionRequest.sourceTrackIDs.first?.int32Value,
              let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: trackID) else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "MetalVideoCompositor", code: -1, userInfo: nil))
            return
        }
        
        let sourceImage = CIImage(cvPixelBuffer: sourcePixelBuffer)
        
        // Apply filter
        colorFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        
        guard let outputImage = colorFilter.outputImage else {
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: sourcePixelBuffer) // Fallback to original
            return
        }
        
        // Render into new buffer
        if let outputPixelBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() {
            renderContext.render(outputImage, to: outputPixelBuffer, bounds: outputImage.extent, colorSpace: nil)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputPixelBuffer)
        } else {
            // Fallback
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: sourcePixelBuffer)
        }
    }
}
