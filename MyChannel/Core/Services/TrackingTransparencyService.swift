//
//  TrackingTransparencyService.swift
//  MyChannel
//
//  App Tracking Transparency (Guideline 5.1.2(i))
//  Requests user permission before any tracking occurs.
//

import Foundation
import AppTrackingTransparency
import AdSupport

@MainActor
final class TrackingTransparencyService {
    static let shared = TrackingTransparencyService()
    private init() {}

    /// Whether the user has granted tracking permission.
    var isTrackingAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// Request ATT permission after a short delay (Apple recommends waiting until
    /// the app is fully active before presenting the prompt).
    func requestTrackingPermissionIfNeeded() {
        // Only request once – don't re-prompt if already determined
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else {
            print("🔒 [ATT] Tracking status already set: \(statusDescription(status))")
            return
        }

        // Apple requires the request to happen after the app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { newStatus in
                Task { @MainActor in
                    print("🔒 [ATT] User responded: \(self.statusDescription(newStatus))")
                    UserDefaults.standard.set(
                        newStatus == .authorized,
                        forKey: "preferences.personalizedAdsEnabled"
                    )
                }
            }
        }
    }

    private func statusDescription(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        @unknown default:    return "unknown"
        }
    }
}
