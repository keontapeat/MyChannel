//
//  ArtistEarningsView.swift
//  MyChannel
//
//  Artist earnings dashboard + Stripe Connect onboarding.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ArtistEarningsView: View {
    let artistId: String
    let artistName: String

    @State private var balance: MusicAvailableBalance?
    @State private var streamsAllTime = 0
    @State private var lifetimePaidCents = 0
    @State private var payoutHistory: [PayoutRecord] = []
    @State private var isLoading = true
    @State private var showWithdrawSheet = false
    @State private var errorMessage: String?
    @State private var onboardingError: String?

    struct PayoutRecord: Identifiable {
        let id: String
        let amountCents: Int
        let totalGrossCents: Int
        let streams: Int
        let periodLabel: String
        let occurredAt: Date
        let status: MusicPayoutStatus
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                earningsSummaryCard
                streamBreakdownCard
                payoutSetupCard
                payoutHistorySection
                hlsInfoCard
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Artist Earnings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEarnings() }
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawSheet(
                artistId: artistId,
                amountCents: balance?.amountCents ?? 0,
                minimumPayoutCents: balance?.minimumPayoutCents ?? 0,
                isReadyForPayout: balance?.isReadyForPayout ?? false,
                payoutAccountReady: balance?.payoutAccountReady ?? false,
                standardDelivery: balance?.standardDelivery ?? ""
            )
        }
    }

    // MARK: - Cards

    private var earningsSummaryCard: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Earnings")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(formatUSDCents(balance?.amountCents ?? 0))
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gross Pending")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(formatUSDCents(balance?.totalGrossCents ?? 0))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lifetime Paid")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(formatUSDCents(lifetimePaidCents))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Button {
                        HapticManager.shared.impact(style: .medium)
                        showWithdrawSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(balance?.payoutAccountReady == true ? "Withdraw" : "Set Up Payouts")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(20),
                alignment: .bottomLeading
            )
        }
        .padding(.horizontal, 20)
    }

    private var streamBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Streams")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)

            HStack(spacing: 12) {
                streamStatTile(
                    icon: "waveform",
                    label: "Unpaid",
                    value: formatNumber(balance?.ownerStreams ?? 0),
                    color: AppTheme.Colors.primary
                )
                streamStatTile(
                    icon: "chart.bar.fill",
                    label: "All Time",
                    value: formatNumber(streamsAllTime),
                    color: .green
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("Qualified plays, collaborator splits, and payout amounts are calculated by the backend.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var payoutSetupCard: some View {
        let payoutAccountReady = balance?.payoutAccountReady == true
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: payoutAccountReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(payoutAccountReady ? .green : .orange)
                Text(payoutAccountReady ? "Stripe Ready for Payouts" : "Connect Stripe to Get Paid")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }

            if !payoutAccountReady {
                Text("Connect your Stripe account to receive monthly payouts directly to your bank account. Takes 2 minutes.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Button {
                    HapticManager.shared.impact(style: .medium)
                    openStripeOnboarding()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "link.circle.fill")
                        Text("Connect Stripe Account")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.4, green: 0.2, blue: 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let onboardingError {
                    Text(onboardingError)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text("Powered by Stripe Connect — bank-level security")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Your account is fully connected with charges and payouts enabled.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var payoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payout History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)

            if payoutHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "banknote")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("No payouts yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("Your first payout will appear after the available balance reaches \(formatUSDCents(balance?.minimumPayoutCents ?? 0)).")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(payoutHistory) { payout in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: payout.status == .paid ? "checkmark.circle.fill" : "clock.fill")
                                    .foregroundColor(payout.status == .paid ? .green : .orange)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payout.periodLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Text("\(formatNumber(payout.streams)) streams")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatUSDCents(payout.amountCents))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                            Text(payoutStatusLabel(payout.status))
                                .font(.system(size: 11))
                                .foregroundColor(payout.status == .paid ? .green : .orange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var hlsInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 22))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("HLS Streaming Active")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Your tracks are auto-converted to HLS for smooth adaptive streaming on all devices.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func streamStatTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 { return String(format: "%.1fM", Double(number) / 1_000_000) }
        if number >= 1_000 { return String(format: "%.1fK", Double(number) / 1_000) }
        return "\(number)"
    }

    private func payoutStatusLabel(_ status: MusicPayoutStatus) -> String {
        switch status {
        case .paid: return "Paid"
        case .partiallyPaid: return "Partially Paid"
        case .owed: return "Owed"
        }
    }

    private func openStripeOnboarding() {
        onboardingError = nil
        guard let refreshURL = URL(string: "https://mychannel.live/stripe/refresh"),
              let returnURL = URL(string: "https://mychannel.live/stripe/return") else {
            onboardingError = "Payout onboarding is temporarily unavailable."
            return
        }

        Task {
            do {
                let link = try await MusicAPIClient.shared.createConnectOnboardingLink(
                    artistId: artistId,
                    email: nil,
                    refreshURL: refreshURL,
                    returnURL: returnURL
                )
                await MainActor.run {
                    UIApplication.shared.open(link.url)
                }
            } catch {
                onboardingError = error.localizedDescription
            }
        }
    }

    // MARK: - Data

    private func loadEarnings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            balance = try await MusicAPIClient.shared.getAvailableBalance(artistId: artistId)
        } catch {
            balance = nil
            errorMessage = error.localizedDescription
        }

        #if canImport(FirebaseFirestore)
        do {
            let database = Firestore.firestore()
            let tracks = try await database.collection("music_tracks")
                .whereField("artistId", isEqualTo: artistId)
                .getDocuments()
            streamsAllTime = tracks.documents.reduce(0) { partial, document in
                partial + (nonNegativeInteger(document.data()["streamCount"]) ?? 0)
            }

            let payoutDocuments = try await database.collection("artist_payouts")
                .whereField("artistId", isEqualTo: artistId)
                .limit(to: 50)
                .getDocuments()
            let records: [PayoutRecord] = payoutDocuments.documents.compactMap { document in
                let data = document.data()
                guard let amountCents = nonNegativeInteger(data["amountCents"]),
                      let totalGrossCents = nonNegativeInteger(data["totalGrossCents"]),
                      totalGrossCents >= amountCents,
                      let statusValue = data["status"] as? String,
                      let status = MusicPayoutStatus(rawValue: statusValue),
                      let timestamp = (data["paidAt"] as? Timestamp)
                        ?? (data["updatedAt"] as? Timestamp)
                        ?? (data["createdAt"] as? Timestamp) else { return nil }
                return PayoutRecord(
                    id: document.documentID,
                    amountCents: amountCents,
                    totalGrossCents: totalGrossCents,
                    streams: nonNegativeInteger(data["streams"]) ?? 0,
                    periodLabel: data["periodLabel"] as? String ?? "Music payout",
                    occurredAt: timestamp.dateValue(),
                    status: status
                )
            }
            payoutHistory = records.sorted { $0.occurredAt > $1.occurredAt }.prefix(20).map { $0 }
            lifetimePaidCents = payoutHistory.reduce(0) { total, record in
                switch record.status {
                case .paid, .partiallyPaid: return total + record.amountCents
                case .owed: return total
                }
            }
        } catch {
            payoutHistory = []
            streamsAllTime = 0
            lifetimePaidCents = 0
            errorMessage = error.localizedDescription
        }
        #else
        payoutHistory = []
        streamsAllTime = 0
        lifetimePaidCents = 0
        #endif
    }

    private func nonNegativeInteger(_ value: Any?) -> Int? {
        if let integer = value as? Int, integer >= 0 { return integer }
        if let integer = value as? Int64,
           integer >= 0,
           integer <= Int64(Int.max) {
            return Int(integer)
        }
        return nil
    }
}

// MARK: - Withdraw Sheet

private struct WithdrawSheet: View {
    let artistId: String
    let amountCents: Int
    let minimumPayoutCents: Int
    let isReadyForPayout: Bool
    let payoutAccountReady: Bool
    let standardDelivery: String

    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    @State private var resultMessage: String?
    @State private var resultStatus: MusicPayoutStatus?
    @State private var didComplete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: payoutAccountReady ? "banknote.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(payoutAccountReady ? AppTheme.Colors.primary : .orange)
                    .padding(.top, 32)

                if payoutAccountReady {
                    payoutContent
                } else {
                    Text("Connect Stripe First")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Stripe must be fully connected with charges and payouts enabled before withdrawing.")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Withdraw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }

    private var payoutContent: some View {
        Group {
            Text("Withdraw \(formatUSDCents(amountCents))")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("The backend will settle the owner share and collaborator splits. \(standardDelivery)")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let resultMessage {
                Text(resultMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(resultColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                HapticManager.shared.impact(style: .medium)
                Task { await requestPayout() }
            } label: {
                HStack {
                    if isRequesting { ProgressView().tint(.white) }
                    Text(didComplete ? "Payout Processed" : "Request Payout")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isReadyForPayout && !didComplete ? AppTheme.Colors.primary : Color.gray
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!isReadyForPayout || isRequesting || didComplete)
            .padding(.horizontal, 24)

            if !isReadyForPayout {
                Text(minimumMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var minimumMessage: String {
        guard minimumPayoutCents > 0 else {
            return "Payout readiness is unavailable. Close and refresh earnings."
        }
        return "Minimum withdrawal is \(formatUSDCents(minimumPayoutCents))."
    }

    private var resultColor: Color {
        switch resultStatus {
        case .paid: return .green
        case .partiallyPaid, .owed: return .orange
        case nil: return .red
        }
    }

    private func requestPayout() async {
        guard !isRequesting, isReadyForPayout else { return }
        isRequesting = true
        resultMessage = nil
        resultStatus = nil
        defer { isRequesting = false }

        do {
            let result = try await MusicAPIClient.shared.requestPayout(
                artistId: artistId,
                payoutType: "standard"
            )
            resultStatus = result.status
            switch result.status {
            case .paid:
                didComplete = true
                resultMessage = "Payout sent successfully."
                HapticManager.shared.notification(type: .success)
            case .partiallyPaid:
                didComplete = true
                let owedCents = result.splits?
                    .filter { $0.status == .owed }
                    .reduce(0) { $0 + $1.amountCents } ?? 0
                resultMessage = "Your payout was sent. \(formatUSDCents(owedCents)) in collaborator shares remains owed until those accounts are ready."
                HapticManager.shared.notification(type: .success)
            case .owed:
                didComplete = true
                let owedCents = result.splits?
                    .filter { $0.status == .owed }
                    .reduce(0) { $0 + $1.amountCents } ?? 0
                resultMessage = "No transfer was sent; \(formatUSDCents(owedCents)) was recorded as owed."
            case nil:
                resultMessage = result.message ?? "Payout could not be processed."
            }
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}

private func formatUSDCents(_ cents: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    let amount = Decimal(cents) / Decimal(100)
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "USD \(cents)¢"
}
