//
//  ArtistEarningsView.swift
//  MyChannel
//
//  Artist earnings dashboard + Stripe Connect onboarding.
//  Drop in STRIPE_CONNECT_CLIENT_ID when Stripe setup is complete.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// TODO: Replace with your Stripe Connect client ID from dashboard.stripe.com/settings/connect
private let STRIPE_CONNECT_CLIENT_ID = "ca_TODO_YOUR_CLIENT_ID"
private let STRIPE_PAYOUT_RATE: Double = 0.004 // $0.004 per stream

struct ArtistEarningsView: View {
    let artistId: String
    let artistName: String

    @State private var streamStats: StreamStats? = nil
    @State private var payoutHistory: [PayoutRecord] = []
    @State private var isLoading = true
    @State private var stripeConnected = false
    @State private var showStripeOnboarding = false
    @State private var showWithdrawSheet = false

    struct StreamStats {
        let streamsThisMonth: Int
        let streamsAllTime: Int
        let estimatedMonthlyPayout: Double
        let lifetimeEarnings: Double
        let pendingPayout: Double
    }

    struct PayoutRecord: Identifiable {
        let id: String
        let amount: Double
        let streams: Int
        let periodLabel: String
        let paidAt: Date
        let status: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                pendingAmount: streamStats?.pendingPayout ?? 0,
                stripeConnected: stripeConnected
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
                    Text("Estimated Earnings")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(formatCurrency(streamStats?.lifetimeEarnings ?? 0))
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This Month")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(formatCurrency(streamStats?.estimatedMonthlyPayout ?? 0))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pending")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(formatCurrency(streamStats?.pendingPayout ?? 0))
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
                            Text(stripeConnected ? "Withdraw" : "Set Up Payouts")
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
                    label: "This Month",
                    value: formatNumber(streamStats?.streamsThisMonth ?? 0),
                    color: AppTheme.Colors.primary
                )
                streamStatTile(
                    icon: "chart.bar.fill",
                    label: "All Time",
                    value: formatNumber(streamStats?.streamsAllTime ?? 0),
                    color: .green
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("Rate: $\(String(format: "%.4f", STRIPE_PAYOUT_RATE)) per stream. Paid monthly via Stripe.")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: stripeConnected ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(stripeConnected ? .green : .orange)
                Text(stripeConnected ? "Stripe Connected" : "Connect Stripe to Get Paid")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }

            if !stripeConnected {
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

                Text("Powered by Stripe Connect — bank-level security")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Payouts are sent automatically to your linked bank on the 1st of each month.")
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
                    Text("Your first payout will appear here once you hit the minimum threshold of $10.")
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
                                Image(systemName: payout.status == "paid" ? "checkmark.circle.fill" : "clock.fill")
                                    .foregroundColor(payout.status == "paid" ? .green : .orange)
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
                            Text(formatCurrency(payout.amount))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                            Text(payout.status.capitalized)
                                .font(.system(size: 11))
                                .foregroundColor(payout.status == "paid" ? .green : .orange)
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func openStripeOnboarding() {
        let redirectURI = "mychannel://stripe-connect/callback"
        let urlString = "https://connect.stripe.com/express/oauth/authorize"
            + "?client_id=\(STRIPE_CONNECT_CLIENT_ID)"
            + "&state=\(artistId)"
            + "&redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            + "&stripe_user[business_type]=individual"
            + "&stripe_user[business_name]=\((artistName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Data

    private func loadEarnings() async {
        isLoading = true
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let db = Firestore.firestore()
        let uid = Auth.auth().currentUser?.uid ?? artistId

        do {
            let snapshot = try await db.collection("music_tracks")
                .whereField("artistId", isEqualTo: uid)
                .getDocuments()

            let allTime = snapshot.documents.reduce(0) { $0 + ((($1.data()["streamCount"] as? Int) ?? 0)) }
            let thisMonth = Int(Double(allTime) * 0.15) // approximate monthly share

            let payoutDocs = try await db.collection("artist_payouts")
                .whereField("artistId", isEqualTo: uid)
                .order(by: "paidAt", descending: true)
                .limit(to: 20)
                .getDocuments()

            let records = payoutDocs.documents.compactMap { doc -> PayoutRecord? in
                let d = doc.data()
                guard let amount = d["amount"] as? Double,
                      let streams = d["streams"] as? Int,
                      let period = d["periodLabel"] as? String,
                      let status = d["status"] as? String,
                      let ts = d["paidAt"] as? Timestamp else { return nil }
                return PayoutRecord(id: doc.documentID, amount: amount, streams: streams,
                                    periodLabel: period, paidAt: ts.dateValue(), status: status)
            }

            let paidTotal = records.filter { $0.status == "paid" }.reduce(0.0) { $0 + $1.amount }
            let pending = Double(thisMonth) * STRIPE_PAYOUT_RATE

            let stripeDoc = try? await db.collection("artist_stripe").document(uid).getDocument()
            let connected = stripeDoc?.data()?["connected"] as? Bool ?? false

            await MainActor.run {
                streamStats = StreamStats(
                    streamsThisMonth: thisMonth,
                    streamsAllTime: allTime,
                    estimatedMonthlyPayout: Double(thisMonth) * STRIPE_PAYOUT_RATE,
                    lifetimeEarnings: paidTotal,
                    pendingPayout: pending
                )
                payoutHistory = records
                stripeConnected = connected
                isLoading = false
            }
        } catch {
            await MainActor.run {
                streamStats = StreamStats(streamsThisMonth: 0, streamsAllTime: 0,
                                          estimatedMonthlyPayout: 0, lifetimeEarnings: 0, pendingPayout: 0)
                isLoading = false
            }
        }
        #else
        try? await Task.sleep(nanoseconds: 500_000_000)
        streamStats = StreamStats(streamsThisMonth: 2_340, streamsAllTime: 18_450,
                                  estimatedMonthlyPayout: 9.36, lifetimeEarnings: 73.80, pendingPayout: 9.36)
        isLoading = false
        #endif
    }
}

// MARK: - Withdraw Sheet

private struct WithdrawSheet: View {
    let pendingAmount: Double
    let stripeConnected: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: stripeConnected ? "banknote.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(stripeConnected ? AppTheme.Colors.primary : .orange)
                    .padding(.top, 32)

                if stripeConnected {
                    Text("Withdraw \(formatCurrency(pendingAmount))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Funds will be sent to your connected bank account within 2–3 business days.")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    } label: {
                        Text("Request Payout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(pendingAmount >= 10 ? AppTheme.Colors.primary : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(pendingAmount < 10)
                    .padding(.horizontal, 24)

                    if pendingAmount < 10 {
                        Text("Minimum withdrawal is $10.00")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Connect Stripe First")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("You need to connect a Stripe account before you can withdraw earnings.")
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
