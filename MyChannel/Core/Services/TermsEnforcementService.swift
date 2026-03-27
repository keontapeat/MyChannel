//
//  TermsEnforcementService.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 📋 Terms & Conditions Enforcement Service
// Ensures terms are always shown and properly accepted
@MainActor
class TermsEnforcementService: ObservableObject {
    static let shared = TermsEnforcementService()
    
    @Published var shouldShowTerms = false
    @Published var termsVersion = "1.0"
    @Published var privacyVersion = "1.0"
    @Published var isLoading = false
    @Published var error: String?
    
    // Terms tracking
    private let currentTermsVersion = "2024.03.22"
    private let currentPrivacyVersion = "2024.03.22"
    private let minimumRequiredVersion = "2024.01.01"
    
    private init() {
        checkTermsCompliance()
    }
    
    // MARK: - Terms Compliance Checking
    
    func checkTermsCompliance() {
        Task {
            await performTermsCheck()
        }
    }
    
    private func performTermsCheck() async {
        guard let userId = AppState.shared.currentUser?.id else {
            // Always show terms for non-authenticated users
            shouldShowTerms = true
            return
        }
        
        do {
            let userTermsStatus = try await getUserTermsStatus(userId: userId)
            let complianceResult = evaluateCompliance(userTermsStatus)
            
            shouldShowTerms = complianceResult.requiresAcceptance
            
            if complianceResult.requiresAcceptance {
                // Log terms enforcement
                EnhancedAnalyticsManager.shared.logEvent("terms_enforcement_triggered", parameters: [
                    "user_id": userId,
                    "reason": complianceResult.reason,
                    "last_accepted_version": userTermsStatus.termsVersion ?? "none",
                    "current_version": currentTermsVersion
                ])
            }
            
        } catch {
            // On error, always show terms for safety
            shouldShowTerms = true
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "TermsEnforcement",
                severity: .warning,
                metadata: ["user_id": userId]
            )
        }
    }
    
    private func getUserTermsStatus(userId: String) async throws -> UserTermsStatus {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = doc.data() else {
            return UserTermsStatus() // New user, no terms accepted
        }
        
        return UserTermsStatus(
            termsVersion: data["acceptedTermsVersion"] as? String,
            privacyVersion: data["acceptedPrivacyVersion"] as? String,
            acceptedAt: (data["termsAcceptedAt"] as? Timestamp)?.dateValue(),
            ipAddress: data["termsAcceptedIP"] as? String,
            deviceInfo: data["termsAcceptedDevice"] as? String
        )
        #else
        return UserTermsStatus()
        #endif
    }
    
    private func evaluateCompliance(_ status: UserTermsStatus) -> ComplianceResult {
        // Rule 1: No terms accepted at all
        guard let acceptedTermsVersion = status.termsVersion,
              let acceptedPrivacyVersion = status.privacyVersion else {
            return ComplianceResult(
                requiresAcceptance: true,
                reason: "no_terms_accepted"
            )
        }
        
        // Rule 2: Terms version is outdated
        if !isVersionCurrent(acceptedTermsVersion, current: currentTermsVersion) {
            return ComplianceResult(
                requiresAcceptance: true,
                reason: "terms_outdated"
            )
        }
        
        // Rule 3: Privacy policy is outdated
        if !isVersionCurrent(acceptedPrivacyVersion, current: currentPrivacyVersion) {
            return ComplianceResult(
                requiresAcceptance: true,
                reason: "privacy_outdated"
            )
        }
        
        // Rule 4: Terms are too old (force re-acceptance every 365 days)
        if let acceptedAt = status.acceptedAt,
           Date().timeIntervalSince(acceptedAt) > 365 * 24 * 60 * 60 {
            return ComplianceResult(
                requiresAcceptance: true,
                reason: "terms_expired"
            )
        }
        
        // Rule 5: Version is below minimum required
        if !isVersionAboveMinimum(acceptedTermsVersion, minimum: minimumRequiredVersion) {
            return ComplianceResult(
                requiresAcceptance: true,
                reason: "below_minimum_version"
            )
        }
        
        return ComplianceResult(
            requiresAcceptance: false,
            reason: "compliant"
        )
    }
    
    private func isVersionCurrent(_ acceptedVersion: String, current: String) -> Bool {
        return acceptedVersion == current
    }
    
    private func isVersionAboveMinimum(_ acceptedVersion: String, minimum: String) -> Bool {
        return acceptedVersion.compare(minimum, options: .numeric) != .orderedAscending
    }
    
    // MARK: - Terms Acceptance
    
    func acceptTerms(userId: String, ipAddress: String? = nil) async throws {
        isLoading = true
        error = nil
        
        do {
            let deviceInfo = await getDeviceInfo()
            let acceptanceData = TermsAcceptanceData(
                userId: userId,
                termsVersion: currentTermsVersion,
                privacyVersion: currentPrivacyVersion,
                acceptedAt: Date(),
                ipAddress: ipAddress ?? "unknown",
                deviceInfo: deviceInfo,
                userAgent: getUserAgent()
            )
            
            try await recordTermsAcceptance(acceptanceData)
            
            // Update local state
            shouldShowTerms = false
            termsVersion = currentTermsVersion
            privacyVersion = currentPrivacyVersion
            
            // Track acceptance
            EnhancedAnalyticsManager.shared.logEvent("terms_accepted", parameters: [
                "user_id": userId,
                "terms_version": currentTermsVersion,
                "privacy_version": currentPrivacyVersion,
                "device_info": deviceInfo
            ])
            
            isLoading = false
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            
            ErrorReportingManager.shared.reportError(
                error,
                context: "TermsAcceptance",
                severity: .error,
                metadata: [
                    "user_id": userId,
                    "terms_version": currentTermsVersion
                ]
            )
            
            throw error
        }
    }
    
    private func recordTermsAcceptance(_ data: TermsAcceptanceData) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Update user document
        try await db.collection("users").document(data.userId).updateData([
            "acceptedTermsVersion": data.termsVersion,
            "acceptedPrivacyVersion": data.privacyVersion,
            "termsAcceptedAt": Timestamp(date: data.acceptedAt),
            "termsAcceptedIP": data.ipAddress,
            "termsAcceptedDevice": data.deviceInfo,
            "termsAcceptedUserAgent": data.userAgent
        ])
        
        // Create audit record
        try await db.collection("terms_acceptances").addDocument(data: [
            "userId": data.userId,
            "termsVersion": data.termsVersion,
            "privacyVersion": data.privacyVersion,
            "acceptedAt": Timestamp(date: data.acceptedAt),
            "ipAddress": data.ipAddress,
            "deviceInfo": data.deviceInfo,
            "userAgent": data.userAgent
        ])
        #endif
    }
    
    private func getDeviceInfo() async -> String {
        #if os(iOS)
        let device = UIDevice.current
        return "\(device.systemName) \(device.systemVersion) - \(device.model)"
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        return "Unknown Device"
        #endif
    }
    
    private func getUserAgent() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "MyChannel/\(appVersion) (\(buildNumber))"
    }
    
    // MARK: - Force Terms Display
    
    func forceTermsDisplay(reason: String = "manual_trigger") {
        shouldShowTerms = true
        
        EnhancedAnalyticsManager.shared.logEvent("terms_force_displayed", parameters: [
            "reason": reason,
            "current_terms_version": currentTermsVersion
        ])
    }
    
    // MARK: - Terms Content Management
    
    func getTermsContent() async -> TermsContent {
        // In production, this would fetch from a CMS or remote config
        return TermsContent(
            termsVersion: currentTermsVersion,
            privacyVersion: currentPrivacyVersion,
            lastUpdated: Date(),
            sections: [
                EnforcementTermsSection(
                    id: "content_policy",
                    title: "Content Policy",
                    icon: "flag",
                    description: "Content depicting violence, hate speech, nudity, exploitation, harassment, or illegal activity is strictly prohibited and will be removed immediately.",
                    details: [
                        "No violent or graphic content",
                        "No hate speech or discrimination",
                        "No nudity or sexual content",
                        "No harassment or bullying",
                        "No illegal activities"
                    ]
                ),
                EnforcementTermsSection(
                    id: "reporting",
                    title: "Reporting & Moderation",
                    icon: "exclamationmark.triangle",
                    description: "You can report objectionable content or abusive users using the flag/report option on any video, comment, or profile. You can also block users to immediately remove their content from your feed. Our moderation team reviews all reports within 24 hours.",
                    details: [
                        "Report inappropriate content",
                        "Block abusive users",
                        "24-hour moderation review",
                        "Community guidelines enforcement"
                    ]
                ),
                EnforcementTermsSection(
                    id: "enforcement",
                    title: "Account Enforcement",
                    icon: "person.crop.circle.badge.exclamationmark",
                    description: "Users who violate our content policy will have their content removed and their accounts suspended or permanently banned. Repeated violations result in permanent removal from the platform.",
                    details: [
                        "Content removal for violations",
                        "Account suspension for repeat offenses",
                        "Permanent ban for severe violations",
                        "Appeal process available"
                    ]
                ),
                EnforcementTermsSection(
                    id: "privacy",
                    title: "Your Privacy",
                    icon: "lock.shield",
                    description: "We respect your privacy and protect your personal data. We do not sell your information. Review our Privacy Policy for full details on how we handle your data.",
                    details: [
                        "No data selling",
                        "Secure data handling",
                        "Transparent privacy practices",
                        "User control over data"
                    ]
                )
            ]
        )
    }
    
    // MARK: - Compliance Monitoring
    
    func startComplianceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                self.checkTermsCompliance()
            }
        }
    }
    
    func getComplianceStatus(userId: String) async -> ComplianceStatus {
        do {
            let userTermsStatus = try await getUserTermsStatus(userId: userId)
            let complianceResult = evaluateCompliance(userTermsStatus)
            
            return ComplianceStatus(
                isCompliant: !complianceResult.requiresAcceptance,
                reason: complianceResult.reason,
                lastAcceptedVersion: userTermsStatus.termsVersion,
                currentVersion: currentTermsVersion,
                acceptedAt: userTermsStatus.acceptedAt,
                daysUntilExpiry: calculateDaysUntilExpiry(userTermsStatus.acceptedAt)
            )
            
        } catch {
            return ComplianceStatus(
                isCompliant: false,
                reason: "error_checking_compliance",
                lastAcceptedVersion: nil,
                currentVersion: currentTermsVersion,
                acceptedAt: nil,
                daysUntilExpiry: 0
            )
        }
    }
    
    private func calculateDaysUntilExpiry(_ acceptedAt: Date?) -> Int {
        guard let acceptedAt = acceptedAt else { return 0 }
        let expiryDate = acceptedAt.addingTimeInterval(365 * 24 * 60 * 60)
        let daysUntilExpiry = Int(expiryDate.timeIntervalSinceNow / (24 * 60 * 60))
        return max(0, daysUntilExpiry)
    }
}

// MARK: - Supporting Types

struct UserTermsStatus {
    let termsVersion: String?
    let privacyVersion: String?
    let acceptedAt: Date?
    let ipAddress: String?
    let deviceInfo: String?
    
    init(termsVersion: String? = nil, privacyVersion: String? = nil, acceptedAt: Date? = nil, ipAddress: String? = nil, deviceInfo: String? = nil) {
        self.termsVersion = termsVersion
        self.privacyVersion = privacyVersion
        self.acceptedAt = acceptedAt
        self.ipAddress = ipAddress
        self.deviceInfo = deviceInfo
    }
}

struct ComplianceResult {
    let requiresAcceptance: Bool
    let reason: String
}

struct TermsAcceptanceData {
    let userId: String
    let termsVersion: String
    let privacyVersion: String
    let acceptedAt: Date
    let ipAddress: String
    let deviceInfo: String
    let userAgent: String
}

struct TermsContent {
    let termsVersion: String
    let privacyVersion: String
    let lastUpdated: Date
    let sections: [EnforcementTermsSection]
}

struct EnforcementTermsSection {
    let id: String
    let title: String
    let icon: String
    let description: String
    let details: [String]
}

struct ComplianceStatus {
    let isCompliant: Bool
    let reason: String
    let lastAcceptedVersion: String?
    let currentVersion: String
    let acceptedAt: Date?
    let daysUntilExpiry: Int
}
