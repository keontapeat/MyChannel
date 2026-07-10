//
//  StripeIdentityPresenter.swift
//  MyChannel
//
//  Presents Stripe IdentityVerificationSheet from SwiftUI.
//  Uses VerificationSession id + ephemeral key secret (iOS SDK contract).
//  The Stripe secret key never leaves the server.
//

import SwiftUI
import UIKit
#if canImport(StripeIdentity)
import StripeIdentity
#endif

@MainActor
enum StripeIdentityPresenter {
    enum Result: Equatable {
        case completed
        case canceled
        case failed(String)
        case unavailable
    }

    /// Present Identity flow from the key window's top view controller.
    /// SECURITY: Never log `ephemeralKeySecret` — treat like a password.
    static func present(sessionId: String, ephemeralKeySecret: String) async -> Result {
        #if canImport(StripeIdentity)
        guard let host = topViewController() else {
            return .failed("Unable to find a view controller to present Identity")
        }

        let logo = UIImage(named: "AppIcon")
            ?? UIImage(systemName: "person.badge.shield.checkmark.fill")
            ?? UIImage()

        return await withCheckedContinuation { continuation in
            let configuration = IdentityVerificationSheet.Configuration(brandLogo: logo)
            let sheet = IdentityVerificationSheet(
                verificationSessionId: sessionId,
                ephemeralKeySecret: ephemeralKeySecret,
                configuration: configuration
            )
            sheet.present(from: host) { result in
                switch result {
                case .flowCompleted:
                    continuation.resume(returning: .completed)
                case .flowCanceled:
                    continuation.resume(returning: .canceled)
                case .flowFailed(let error):
                    continuation.resume(returning: .failed(error.localizedDescription))
                @unknown default:
                    continuation.resume(returning: .failed("Unknown Identity result"))
                }
            }
        }
        #else
        _ = sessionId
        _ = ephemeralKeySecret
        return .unavailable
        #endif
    }

    private static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
