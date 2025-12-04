import UIKit

enum Orientation {
    static func lock(_ orientation: UIInterfaceOrientationMask) {
        UIDevice.current.setValue(orientation == .landscape ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        // Use scene-based rotation update for iOS 16+
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
    static func unlock() { lock(.portrait) }
}


