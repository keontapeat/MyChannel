//
//  CreatorMerchShelfView.swift
//  MyChannel
//
//  Buyer-facing merch shelf for a creator. Lists the creator's active physical
//  products from `creator_products` and opens MerchCheckoutSheet (Stripe, not
//  IAP) to purchase. Drop this into a profile/channel page.
//
//  Gated by AppConfig.Features.enableProfileMerch so it stays dark until the
//  Stripe live rail + Connect onboarding are verified.
//

import SwiftUI

struct CreatorMerchShelfView: View {
    let creatorId: String
    var creatorName: String = "this creator"

    @StateObject private var merchService = CreatorMerchFirestoreService.shared
    @State private var products: [CreatorProduct] = []
    @State private var isLoading = true
    @State private var enabled = false
    @State private var checkoutProduct: CreatorProduct?

    private var purchasable: [CreatorProduct] {
        products.filter { $0.isActive && $0.stock > 0 }
    }

    var body: some View {
        Group {
            if !AppConfig.Features.enableProfileMerch {
                EmptyView()
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(24)
            } else if !enabled || purchasable.isEmpty {
                EmptyView()
            } else {
                shelf
            }
        }
        .task { await load() }
        .sheet(item: $checkoutProduct) { product in
            MerchCheckoutSheet(product: product) {
                Task { await load() }
            }
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bag.fill").foregroundColor(.orange)
                Text("Merch")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(purchasable) { product in
                        Button { checkoutProduct = product } label: {
                            MerchShelfCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Physical items ship to your address. Secure checkout by Stripe.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        guard AppConfig.Features.enableProfileMerch, !creatorId.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        let on = await merchService.isMerchEnabled(for: creatorId)
        let items = (try? await merchService.getProducts(for: creatorId)) ?? []
        await MainActor.run {
            enabled = on
            products = items
            isLoading = false
        }
    }
}

private struct MerchShelfCard: View {
    let product: CreatorProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: product.imageSystemName)
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .frame(width: 140, height: 110)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

            Text(product.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text(String(format: "$%.2f", product.price))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
            Text("Buy")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.primary, in: Capsule())
        }
        .frame(width: 150)
    }
}
