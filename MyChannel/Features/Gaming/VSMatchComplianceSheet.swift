//
//  VSMatchComplianceSheet.swift
//  MyChannel
//
//  🔒 Real-money wagering onboarding gate. Presented before a user can create or
//  accept a VS Match when they haven't yet cleared compliance. Lets the user
//  satisfy the self-serviceable requirements (18+ age verification, Terms of
//  Service acceptance) and clearly surfaces the ones that can't be resolved in
//  the app (KYC for $500+, region, account status, daily limit).
//
//  Enforcement authority still lives in VSMatchComplianceService + the escrow
//  Cloud Function. This sheet is UX only — clearing it here does not by itself
//  authorize a payout.
//

import SwiftUI

struct VSMatchComplianceSheet: View {
    let userId: String
    let wagerAmount: Double
    /// Called once the user has cleared every applicable requirement.
    var onCleared: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    // Requirement state
    @State private var ageVerified = false
    @State private var termsAccepted = false
    @State private var kycStatus: KYCStatus = .notStarted
    @State private var regionAllowed = true
    @State private var accountActive = true
    @State private var withinDailyLimit = true

    // Age-entry input
    @State private var dateOfBirth = Calendar.current.date(
        byAdding: .year, value: -18, to: Date()
    ) ?? Date()

    private let compliance = VSMatchComplianceService.shared

    private var requiresKYC: Bool { WagerPolicy.requiresKYC(amountDollars: wagerAmount) }

    /// Every applicable requirement satisfied → the user may proceed.
    private var isFullyCleared: Bool {
        ageVerified
            && termsAccepted
            && regionAllowed
            && accountActive
            && withinDailyLimit
            && (!requiresKYC || kycStatus == .approved)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if isLoading {
                        ProgressView("Checking eligibility…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        ageSection
                        termsSection
                        if requiresKYC { kycSection }
                        blockersSection
                        if let errorMessage {
                            feedback(errorMessage, color: .red, icon: "exclamationmark.triangle.fill")
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Eligibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        HapticManager.shared.notification(type: .success)
                        onCleared()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!isFullyCleared)
                }
            }
            .task { await refresh() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.primary)
            Text("Real-Money Eligibility")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("VS Matches wager real money. Complete these one-time checks to compete.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Age (18+)

    private var ageSection: some View {
        requirementCard(
            title: "Age Verification (18+)",
            done: ageVerified,
            icon: "person.text.rectangle.fill"
        ) {
            if ageVerified {
                Text("Your age has been verified.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        "Date of Birth",
                        selection: $dateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    Button {
                        Task { await verifyAge() }
                    } label: {
                        actionLabel("Verify Age")
                    }
                    .disabled(isWorking)
                }
            }
        }
    }

    // MARK: - Terms of Service

    private var termsSection: some View {
        requirementCard(
            title: "Terms of Service",
            done: termsAccepted,
            icon: "doc.text.fill"
        ) {
            if termsAccepted {
                Text("You've accepted the current VS Match terms (v\(WagerPolicy.currentTermsVersion)).")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("I confirm this is a skill-based competition, I am wagering my own funds, and I accept the VS Match Terms of Service and Responsible Play policy.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Button {
                        Task { await acceptTerms() }
                    } label: {
                        actionLabel("Accept & Continue")
                    }
                    .disabled(isWorking)
                }
            }
        }
    }

    // MARK: - KYC ($500+)

    private var kycSection: some View {
        requirementCard(
            title: "Identity Verification (KYC)",
            done: kycStatus == .approved,
            icon: "creditcard.and.123"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(kycMessage)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)

                if kycStatus == .notStarted || kycStatus == .rejected || kycStatus == .expired {
                    Button {
                        Task { await startKYC() }
                    } label: {
                        actionLabel(kycStatus == .notStarted ? "Verify Identity" : "Re-verify Identity")
                    }
                    .disabled(isWorking)
                    .accessibilityLabel("Start identity verification")
                }
            }
        }
    }

    private var kycMessage: String {
        switch kycStatus {
        case .approved:
            return "Your identity is verified."
        case .pending:
            return "Your identity verification is under review. You'll be able to place wagers over $500 once it's approved."
        case .rejected:
            return "Identity verification was declined. You can try again, or contact support."
        case .expired:
            return "Your identity verification expired. Please re-verify to wager over $500."
        case .notStarted:
            return "Wagers over $500 require identity verification via Stripe Identity (government ID + selfie)."
        }
    }

    // MARK: - Non-self-serviceable blockers (region / account / daily limit)

    @ViewBuilder
    private var blockersSection: some View {
        if !regionAllowed {
            blockerRow("Real-money play isn't available in your region.")
        }
        if !accountActive {
            blockerRow("Your account is not active for wagering. Contact support.")
        }
        if !withinDailyLimit {
            blockerRow("This wager exceeds your daily limit. Try a smaller amount or come back tomorrow.")
        }
    }

    private func blockerRow(_ text: String) -> some View {
        feedback(text, color: .orange, icon: "hand.raised.fill")
    }

    // MARK: - Reusable pieces

    private func requirementCard<Content: View>(
        title: String,
        done: Bool,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .foregroundColor(done ? .green : AppTheme.Colors.primary)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.surface))
    }

    private func actionLabel(_ text: String) -> some View {
        HStack {
            if isWorking {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text(text).font(.system(size: 15, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(AppTheme.Colors.primary)
        .cornerRadius(12)
    }

    private func feedback(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
    }

    // MARK: - Actions

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        async let age = compliance.isAgeVerified(userId: userId)
        async let terms = compliance.hasAcceptedTerms(userId: userId)
        async let kyc = compliance.getKYCStatus(userId: userId)
        async let region = compliance.isRegionAllowed(userId: userId)
        async let status = compliance.getAccountStatus(userId: userId)
        async let wageredToday = compliance.getDailyWagerAmount(userId: userId)
        async let limit = compliance.getDailyWagerLimit(userId: userId)

        ageVerified = await age
        termsAccepted = await terms
        kycStatus = await kyc
        regionAllowed = await region
        accountActive = (await status) == .active
        withinDailyLimit = WagerPolicy.isWithinDailyLimit(
            alreadyWagered: await wageredToday,
            newWager: wagerAmount,
            limit: await limit
        )
    }

    private func verifyAge() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await compliance.verifyAgeForWagering(userId: userId, dateOfBirth: dateOfBirth)
            ageVerified = true
            HapticManager.shared.notification(type: .success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }

    private func acceptTerms() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await compliance.acceptTermsOfService(
                userId: userId,
                version: WagerPolicy.currentTermsVersion
            )
            termsAccepted = true
            HapticManager.shared.notification(type: .success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }

    private func startKYC() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await compliance.startKYCVerification(userId: userId)
            guard
                let sessionId = result.stripeIdentitySessionId, !sessionId.isEmpty,
                let ephemeralKey = result.stripeIdentityEphemeralKeySecret, !ephemeralKey.isEmpty
            else {
                errorMessage = "Could not start identity verification. Try again."
                HapticManager.shared.notification(type: .error)
                return
            }

            let presentation = await StripeIdentityPresenter.present(
                sessionId: sessionId,
                ephemeralKeySecret: ephemeralKey
            )
            switch presentation {
            case .completed:
                // Webhook is authoritative; optimistically mark pending until approved.
                kycStatus = .pending
                HapticManager.shared.notification(type: .success)
                // Refresh in case webhook already flipped to approved (fast path / test mode).
                kycStatus = await compliance.getKYCStatus(userId: userId)
            case .canceled:
                errorMessage = "Identity verification was canceled."
                HapticManager.shared.impact(style: .light)
            case .failed(let message):
                errorMessage = message
                HapticManager.shared.notification(type: .error)
            case .unavailable:
                // Session created server-side; user can finish later once SDK is linked.
                kycStatus = .pending
                errorMessage = "Identity session started. Finish verification when prompted, or try again after updating the app."
                HapticManager.shared.notification(type: .warning)
            }
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }
}

#Preview {
    VSMatchComplianceSheet(userId: "preview", wagerAmount: 50) {}
}
