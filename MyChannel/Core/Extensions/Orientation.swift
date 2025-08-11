import UIKit

enum Orientation {
    static func lock(_ orientation: UIInterfaceOrientationMask) {
        UIDevice.current.setValue(orientation == .landscape ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    static func unlock() { lock(.portrait) }
}


