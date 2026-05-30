import Foundation
import HomeKit
import UIKit

/// Phase 97: HomeKit Smart Lights Sync
/// Extracts the dominant color of the current video frame and updates the user's HomeKit smart lights to match (Ambilight effect).
@MainActor
final class HomeKitSyncEngine: NSObject, ObservableObject {
    static let shared = HomeKitSyncEngine()
    
    private let homeManager = HMHomeManager()
    @Published var isHomeKitReady = false
    
    private var lastColorUpdate = Date.distantPast
    
    private override init() {
        super.init()
        homeManager.delegate = self
    }
    
    /// Called periodically with a captured frame from the video
    func syncLights(with frame: UIImage) {
        guard isHomeKitReady, Date().timeIntervalSince(lastColorUpdate) > 1.0 else { return }
        
        Task.detached {
            guard let dominantColor = self.extractDominantColor(from: frame) else { return }
            
            await MainActor.run {
                self.updateLights(to: dominantColor)
                self.lastColorUpdate = Date()
            }
        }
    }
    
    private func updateLights(to color: UIColor) {
        guard let primaryHome = homeManager.primaryHome else { return }
        
        for accessory in primaryHome.accessories {
            for service in accessory.services where service.serviceType == HMServiceTypeLightbulb {
                for characteristic in service.characteristics {
                    if characteristic.characteristicType == HMCharacteristicTypeHue {
                        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                        
                        characteristic.writeValue(hue * 360) { error in
                            if let error = error {
                                print("⚠️ [HomeKit] Failed to set Hue: \(error)")
                            }
                        }
                    } else if characteristic.characteristicType == HMCharacteristicTypeSaturation {
                        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                        
                        characteristic.writeValue(saturation * 100) { error in
                            if let error = error {
                                print("⚠️ [HomeKit] Failed to set Saturation: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Extremely naive dominant color extraction (just center pixel for speed).
    /// In production, use CoreImage K-Means or CIAreaAverage.
    nonisolated private func extractDominantColor(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData: [UInt8] = [0, 0, 0, 0]
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        let r = CGFloat(pixelData[0]) / 255.0
        let g = CGFloat(pixelData[1]) / 255.0
        let b = CGFloat(pixelData[2]) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension HomeKitSyncEngine: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.isHomeKitReady = manager.primaryHome != nil
            if self.isHomeKitReady {
                print("💡 [HomeKit] Found primary home. Ready to sync smart lights.")
            } else {
                print("⚠️ [HomeKit] No primary home found.")
            }
        }
    }
}
