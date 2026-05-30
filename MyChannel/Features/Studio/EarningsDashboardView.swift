//
//  EarningsDashboardView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct EarningsDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var service = CreatorEconomyService.shared
    @State private var earnings: CreatorEarnings? = nil
    @State private var isLoading = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                totals
                breakdown
                payoutCard
            }
            .padding()
            .frame(maxWidth: horizontalSizeClass == .regular ? 900 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .task { await load() }
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Estimated Revenue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("$\(earnings?.creatorShare ?? 0, specifier: "%.2f")")
                    .font(.system(size: 32, weight: .bold))
                Text("90% creator share")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private var totals: some View {
        HStack(spacing: 12) {
            metric("Total Revenue", amount: earnings?.totalRevenue ?? 0, color: .blue)
            metric("Your Share", amount: earnings?.creatorShare ?? 0, color: .green)
            metric("Platform Fee", amount: earnings?.platformFee ?? 0, color: .orange)
        }
    }
    
    private func metric(_ title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("$\(amount, specifier: "%.2f")").font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Revenue Breakdown").font(.headline)
            GroupBox {
                let columns = horizontalSizeClass == .regular
                    ? [GridItem(.flexible()), GridItem(.flexible())]
                    : [GridItem(.flexible())]
                
                LazyVGrid(columns: columns, spacing: 16) {
                    row("Ads", earnings?.revenueBreakdown.adRevenue ?? 0)
                    row("Tips", earnings?.revenueBreakdown.tipRevenue ?? 0)
                    row("Memberships", earnings?.revenueBreakdown.membershipRevenue ?? 0)
                    row("Merch", earnings?.revenueBreakdown.merchandiseRevenue ?? 0)
                    row("Courses", earnings?.revenueBreakdown.courseRevenue ?? 0)
                    row("Brand Deals", earnings?.revenueBreakdown.brandDealRevenue ?? 0)
                    row("NFTs", earnings?.revenueBreakdown.nftRevenue ?? 0)
                    row("Live", earnings?.revenueBreakdown.liveStreamRevenue ?? 0)
                }
                .padding(.vertical, 6)
            }
        }
    }
    
    private func row(_ title: String, _ amount: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("$\(amount, specifier: "%.2f")")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
    
    private var payoutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payouts").font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available to withdraw")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(earnings?.creatorShare ?? 0, specifier: "%.2f")")
                        .font(.title3).fontWeight(.bold)
                }
                Spacer()
                NavigationLink("History") { PayoutsHistoryView().environmentObject(appState) }
                Button("Withdraw") {
                    Task {
                        guard let uid = appState.currentUser?.id ?? User.sampleUsers.first?.id else { return }
                        _ = try? await service.requestWithdrawal(creatorId: uid, amount: min(earnings?.creatorShare ?? 0, 100.0))
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .disabled((earnings?.creatorShare ?? 0) <= 0)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            HStack(spacing: 12) {
                NavigationLink(destination: PayoutSettingsView()) {
                    Label("Payout Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func load() async {
        guard let userId = appState.currentUser?.id ?? User.sampleUsers.first?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let e = try await service.getCreatorEarnings(for: userId)
            earnings = e
        } catch {
            print("Earnings load error: \(error)")
        }
    }
}

#Preview("Earnings Dashboard") {
    EarningsDashboardView()
        .environmentObject(AppState())
}


