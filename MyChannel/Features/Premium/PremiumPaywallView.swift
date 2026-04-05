import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                benefits
                if AppConfig.Features.enableSubscriptions {
                    productList
                    restore
                    Spacer()
                    footer
                } else {
                    // 🔥 FIX 2.1(b): Hide purchase UI when IAPs not submitted
                    Text("Coming Soon")
                        .font(.title2.bold())
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding()
            .navigationTitle("Music Premium")
            .task {
                guard AppConfig.Features.enableSubscriptions else { return }
                await store.loadProducts()
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.quarternote.3").font(.system(size: 44)).foregroundColor(AppTheme.Colors.primary)
            Text("Unlimited Music")
                .font(.system(size: 24, weight: .bold))
            Text("Listen to any track, ad‑free. Support local artists.")
                .foregroundColor(.secondary)
        }
    }
    
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Unlimited streaming")
            label("High‑quality audio")
            label("Support your city’s artists")
            label("Cancel anytime")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func label(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
            Text(text)
        }
    }
    
    private var productList: some View {
        VStack(spacing: 12) {
            if store.products.isEmpty {
                ProgressView().padding()
            }
            ForEach(store.products, id: \.id) { p in
                Button {
                    Task { _ = await store.purchase(p); if await store.hasActiveSubscription() { dismiss() } }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.displayName).font(.headline)
                            Text(p.displayPrice).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [AppTheme.Colors.primary.opacity(0.12), AppTheme.Colors.secondary.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var restore: some View {
        HStack(spacing: 16) {
            Button("Restore Purchases") { Task { await store.restore(); if await store.hasActiveSubscription() { dismiss() } } }
                .font(.footnote)
                .foregroundColor(AppTheme.Colors.primary)
            Button("Manage Subscription") { UIApplication.shared.sendAction(#selector(AppActions.openManageSubscriptions), to: nil, from: nil, for: nil) }
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var footer: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account.")
                .font(.footnote).foregroundColor(.secondary)
            Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.footnote).foregroundColor(.secondary)
        }
    }
}


