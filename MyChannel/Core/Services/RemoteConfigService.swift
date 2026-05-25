//
//  RemoteConfigService.swift
//  MyChannel
//
//  Firebase Remote Config wrapper with real-time fetch,
//  default values, and change listeners.
//

import Foundation
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

@MainActor
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()
    private init() {}

    @Published private(set) var config: [String: Any] = [:]
    @Published private(set) var lastFetchAt: Date?

    func fetchDefaults() async throws {
        #if canImport(FirebaseRemoteConfig)
        let rc = RemoteConfig.remoteConfig()
        let defaults: [String: NSObject] = [
            "enable_dark_mode": NSNumber(value: true),
            "max_video_quality": "1080p" as NSString,
            "ad_refresh_interval_sec": NSNumber(value: 30),
            "enable_experimental_features": NSNumber(value: false),
            "min_app_version": "1.0.0" as NSString,
            "maintenance_mode": NSNumber(value: false),
            "feature_rollout_pct": NSNumber(value: 100)
        ]
        rc.setDefaults(defaults)
        #endif
    }

    func fetchRemote() async throws {
        #if canImport(FirebaseRemoteConfig)
        let rc = RemoteConfig.remoteConfig()
        rc.configSettings = RemoteConfigSettings()
        rc.configSettings.minimumFetchInterval = 3600
        try await rc.fetchAndActivate()
        lastFetchAt = Date()
        let keys = rc.keys(withPrefix: "enable_") + rc.keys(withPrefix: "max_") + rc.keys(withPrefix: "min_") + rc.keys(withPrefix: "maintenance_") + rc.keys(withPrefix: "feature_") + rc.keys(withPrefix: "ad_")
        for key in keys {
            config[key] = rc[key].stringValue ?? rc[key].boolValue
        }
        #endif
    }

    func boolValue(for key: String) -> Bool {
        if let val = config[key] as? Bool { return val }
        if let val = config[key] as? NSNumber { return val.boolValue }
        return false
    }

    func stringValue(for key: String) -> String {
        if let val = config[key] as? String { return val }
        return ""
    }

    func intValue(for key: String) -> Int {
        if let val = config[key] as? Int { return val }
        if let val = config[key] as? NSNumber { return val.intValue }
        return 0
    }
}
