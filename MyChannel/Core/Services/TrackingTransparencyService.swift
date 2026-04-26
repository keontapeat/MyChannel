//
//  TrackingTransparencyService.swift
//  MyChannel
//
//  App Tracking Transparency (ATT) request management,
//  authorization status tracking, and consent persistence.
//

import Foundation
import AppTrackingTransparency
import AdSupport

@MainActor
final class TrackingTransparencyService: ObservableObject {
    static let shared = TrackingTransparencyService()
    private init() {}
    @Published private(set) var authorizationStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published private(set) var idfa: String = ""

    func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        authorizationStatus = status
        if status == .authorized {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
        return status
    }

    func checkStatus() {
        authorizationStatus = ATTrackingManager.trackingAuthorizationStatus
        if authorizationStatus == .authorized {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
    }

    var canTrack: Bool { authorizationStatus == .authorized }
    var shouldPrompt: Bool { authorizationStatus == .notDetermined }
}
