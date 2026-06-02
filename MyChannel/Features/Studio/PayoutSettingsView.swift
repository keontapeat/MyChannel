//
//  PayoutSettingsView.swift
//  MyChannel
//
//  Production-grade Stripe Connect onboarding + payout settings.
//  Creators connect their bank account via Stripe's hosted Express onboarding
//  flow — MyChannel never touches raw bank/routing numbers (PCI compliance).
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Connect Status Model

struct ConnectStatus: Codable {
    let connected: Bool
    let payoutsEnabled: Bool
    let chargesEnabled: Bool?
    let status: String?
    let detailsSubmitted: Bool?
}

// MARK: - PayoutSettingsView

struct PayoutSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    @State private var connectStatus: ConnectStatus?
    @State private var isLoading = true
    @State private var isOpeningConnect = false
    @State private var errorMessage: String?
    @State private var showSuccessBanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard
                if connectStatus?.payoutsEnabled == true {
                    payoutsEnabledSection
                } else {
                    connectSection
                }
                complianceNote
            }
            .padding(20)
        }
        .navigationTitle("Payout Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStatus() }
        .overlay(alignment: .top) {
            if showSuccessBanner {
                successBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccessBanner)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: statusIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(statusSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isLoading {
                ProgressView()
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Connect Section (not yet onboarded)

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect your bank account")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("MyChannel uses Stripe to securely send your earnings directly to your bank. You'll be taken to Stripe's secure onboarding — we never see your bank details.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                featureRow(icon: "lock.shield.fill", color: .green,
                           title: "Bank-level security",
                           subtitle: "Stripe is PCI DSS Level 1 certified")
                featureRow(icon: "bolt.fill", color: .orange,
                           title: "Fast payouts",
                           subtitle: "Funds arrive in 1–2 business days")
                featureRow(icon: "globe", color: .blue,
                           title: "150+ countries",
                           subtitle: "USD, EUR, GBP, CAD and more")
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
            }

            Button(action: { Task { await openConnectOnboarding() } }) {
                HStack(spacing: 10) {
                    if isOpeningConnect {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    Text(isOpeningConnect ? "Opening Stripe…" : "Connect Bank Account")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isOpeningConnect)
            .accessibilityLabel("Connect bank account via Stripe")
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Payouts Enabled Section

    private var payoutsEnabledSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Payout account active")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 22))
            }

            Text("Your bank account is connected and payouts are enabled. Withdraw your earnings from the Earnings tab anytime.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Update bank account via Stripe dashboard
            Button(action: { Task { await openConnectOnboarding() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Update bank account")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .foregroundColor(AppTheme.Colors.primary)
                .cornerRadius(12)
            }
            .disabled(isOpeningConnect)
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Compliance Note

    private var complianceNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundColor(AppTheme.Colors.textSecondary)
                .font(.system(size: 14))
                .padding(.top, 1)
            Text("Payouts are processed by Stripe. MyChannel takes a 10% platform fee; you keep 90% of all earnings. Stripe may require identity verification for payouts above certain thresholds.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Stripe onboarding opened successfully")
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Status Computed Properties

    private var statusColor: Color {
        guard !isLoading else { return .gray }
        if connectStatus?.payoutsEnabled == true { return .green }
        if connectStatus?.connected == true { return .orange }
        return .gray
    }

    private var statusIcon: String {
        guard !isLoading else { return "clock" }
        if connectStatus?.payoutsEnabled == true { return "checkmark.circle.fill" }
        if connectStatus?.connected == true { return "exclamationmark.circle.fill" }
        return "creditcard"
    }

    private var statusTitle: String {
        guard !isLoading else { return "Checking status…" }
        if connectStatus?.payoutsEnabled == true { return "Payouts enabled" }
        if connectStatus?.connected == true { return "Setup incomplete" }
        return "Not connected"
    }

    private var statusSubtitle: String {
        guard !isLoading else { return "Loading your payout account" }
        if connectStatus?.payoutsEnabled == true { return "Earnings are paid out to your bank account" }
        if connectStatus?.connected == true { return "Finish Stripe onboarding to enable payouts" }
        return "Connect a bank account to receive earnings"
    }

    // MARK: - Actions

    private func loadStatus() async {
        guard let uid = appState.currentUser?.id else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let status: ConnectStatus = try await NetworkService.shared.get(
                endpoint: .custom("/pay/connect/status/\(uid)"),
                responseType: ConnectStatus.self
            )
            await MainActor.run { self.connectStatus = status }
        } catch {
            // Offline or backend unavailable — show not-connected state
            await MainActor.run {
                self.connectStatus = ConnectStatus(
                    connected: false, payoutsEnabled: false,
                    chargesEnabled: false, status: nil, detailsSubmitted: false
                )
            }
        }
    }

    private func openConnectOnboarding() async {
        guard let uid = appState.currentUser?.id else {
            errorMessage = "Sign in required to connect payouts."
            return
        }
        isOpeningConnect = true
        errorMessage = nil
        defer { isOpeningConnect = false }
        do {
            let url = try await PayAPIService.shared.createConnectLink(userId: uid)
            await MainActor.run {
                openURL(url)
                showSuccessBanner = true
            }
            // Hide banner after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { showSuccessBanner = false }
            // Reload status after returning from Stripe
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await loadStatus()
        } catch {
            await MainActor.run {
                errorMessage = "Could not open Stripe onboarding. Please try again."
            }
        }
    }
}

#Preview {
    NavigationStack {
        PayoutSettingsView()
            .environmentObject(AppState.shared)
    }
}
