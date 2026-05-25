import Foundation
import UIKit
import SwiftUI

@objc final class AppActions: NSObject {
    @objc static func presentMusicPaywall(_ sender: Any?) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let root = window.rootViewController else { return }
        let hosting = UIHostingController(rootView: PremiumPaywallView())
        hosting.modalPresentationStyle = .formSheet
        root.present(hosting, animated: true)
    }

    @objc static func openManageSubscriptions(_ sender: Any?) {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
}


