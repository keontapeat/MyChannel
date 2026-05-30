import UIKit

/// Phase 80: Dynamic App Icon Engine
/// Allows users to unlock and swap their home screen app icon dynamically.
@MainActor
final class AppIconEngine: ObservableObject {
    static let shared = AppIconEngine()
    
    @Published var currentIconName: String?
    
    private init() {
        self.currentIconName = UIApplication.shared.alternateIconName
    }
    
    /// Changes the app icon to the specified alternate icon name.
    /// - Parameter iconName: The name of the alternate icon (defined in Info.plist), or nil to restore default.
    func changeAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ [AppIconEngine] Device does not support alternate icons.")
            return
        }
        
        // Prevent unnecessary changes
        guard UIApplication.shared.alternateIconName != iconName else { return }
        
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            if let error = error {
                print("⚠️ [AppIconEngine] Failed to change app icon: \(error)")
            } else {
                print("✨ [AppIconEngine] Successfully changed app icon to: \(iconName ?? "Default")")
                self?.currentIconName = iconName
            }
        }
    }
}
