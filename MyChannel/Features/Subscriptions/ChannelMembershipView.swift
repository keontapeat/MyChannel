//
//  ChannelMembershipView.swift
//  MyChannel
//
//  YouTube-parity channel memberships — viewers can join a creator's membership
//  tiers (Supporter → Fan → Superfan) via StoreKit 2 IAP, unlocking perks
//  like exclusive posts, custom badges, and member-only live streams.
//

import SwiftUI
import StoreKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ChannelMembershipView: View {
    let channelId: String
    let channelName: String
    let channelAvatarURL: String?

    @Environment(\.dismiss) private var dismiss
    @State private var tiers: [MembershipTier] = MembershipTier.defaultTiers
    @State private var activeTier: MembershipTier?
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false

    struct MembershipTier: Identifiable {
        let id: String
        let name: String
        let priceDisplay: String
        let iapProductId: String
        let color: Color
        let badge: String
        let perks: [String]

        static let defaultTiers: [MembershipTier] = [
            MembershipTier(
                id: "supporter",
                name: "Supporter",
                priceDisplay: "$1.99/mo",
                iapProductId: "com.mychannel.membership.supporter",
                color: .blue,
                badge: "🔵",
                perks: ["Supporter badge in chat", "Exclusive members-only posts"]
            ),
            MembershipTier(
                id: "fan",
                name: "Fan",
                priceDisplay: "$4.99/mo",
                iapProductId: "com.mychannel.membership.fan",
                color: .purple,
                badge: "💜",
                perks: ["Fan badge in chat", "Exclusive posts", "Early video access", "Members-only live streams"]
            ),
            MembershipTier(
                id: "superfan",
                name: "Superfan",
                priceDisplay: "$9.99/mo",
                iapProductId: "com.mychannel.membership.superfan",
                color: Color(red: 1, green: 0.75, blue: 0),
                badge: "⭐️",
                perks: ["Superfan gold badge", "All Fan perks", "Monthly shoutout", "Direct DM access"]
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                if showSuccess {
                    successView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Join \(channelName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .alert("Membership Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Purchase could not be completed.")
            }
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: channelAvatarURL ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.surface)
                            .overlay(
                                Text(String(channelName.prefix(1)))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())

                    Text("Support \(channelName)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Join to access exclusive perks and show your support.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Tier cards
                ForEach(tiers) { tier in
                    tierCard(tier)
                }

                // Join button
                if let tier = activeTier {
                    Button {
                        joinMembership(tier)
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView().progressViewStyle(.circular).tint(.white)
                            }
                            Text(isProcessing ? "Processing…" : "Join \(tier.name) — \(tier.priceDisplay)")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 26).fill(tier.color))
                        .shadow(color: tier.color.opacity(0.4), radius: 8, y: 4)
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Join \(tier.name) membership for \(tier.priceDisplay)")
                }

                Text("Recurring billing • Cancel anytime • Creators receive 70%")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Guideline 3.1.1 — Restore required for auto-renewable memberships
                Button {
                    restorePurchases()
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(12)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 20)
                .accessibilityLabel("Restore previous membership purchases")
            }
            .padding(.vertical, 20)
        }
    }

    private func tierCard(_ tier: MembershipTier) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                activeTier = activeTier?.id == tier.id ? nil : tier
            }
            HapticManager.shared.impact(style: .light)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tier.badge)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text(tier.priceDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: activeTier?.id == tier.id ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(activeTier?.id == tier.id ? tier.color : AppTheme.Colors.textTertiary)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tier.perks, id: \.self) { perk in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(tier.color)
                            Text(perk)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(activeTier?.id == tier.id ? tier.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .scaleEffect(activeTier?.id == tier.id ? 1.02 : 1.0)
        .accessibilityLabel("\(tier.name) membership, \(tier.priceDisplay)")
        .accessibilityAddTraits(activeTier?.id == tier.id ? .isSelected : [])
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.1)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            VStack(spacing: 8) {
                Text("Welcome to \(channelName)!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Your \(activeTier?.name ?? "") membership is active. Enjoy your perks!")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Start Exploring")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(26)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - IAP Purchase
    private func restorePurchases() {
        isProcessing = true
        HapticManager.shared.impact(style: .light)
        Task { @MainActor in
            do {
                try await AppStore.sync()
                let productIds = Set(MembershipTier.defaultTiers.map(\.iapProductId))
                var restoredTier: MembershipTier?
                for await entitlement in Transaction.currentEntitlements {
                    guard case .verified(let transaction) = entitlement,
                          productIds.contains(transaction.productID),
                          let tier = tiers.first(where: { $0.iapProductId == transaction.productID })
                    else { continue }
                    await recordMembership(tier: tier)
                    restoredTier = tier
                }
                isProcessing = false
                if restoredTier != nil {
                    showSuccess = true
                    HapticManager.shared.successPattern()
                } else {
                    errorMessage = "No previous membership purchases found for this Apple ID."
                    showError = true
                }
            } catch {
                isProcessing = false
                errorMessage = "Unable to restore purchases. Please try again."
                showError = true
            }
        }
    }

    private func joinMembership(_ tier: MembershipTier) {
        isProcessing = true
        HapticManager.shared.impact(style: .medium)
        Task { @MainActor in
            do {
                let products = try await Product.products(for: [tier.iapProductId])
                guard let product = products.first else {
                    // Never unlock memberships without a verified IAP in Release (3.1.1)
#if DEBUG
                    await recordMembership(tier: tier)
                    isProcessing = false
                    showSuccess = true
                    HapticManager.shared.successPattern()
#else
                    isProcessing = false
                    errorMessage = "Memberships are temporarily unavailable. Please try again later."
                    showError = true
#endif
                    return
                }
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await recordMembership(tier: tier)
                        await transaction.finish()
                        isProcessing = false
                        showSuccess = true
                        HapticManager.shared.successPattern()
                    case .unverified:
                        isProcessing = false
                        errorMessage = "Purchase could not be verified."
                        showError = true
                    }
                case .userCancelled:
                    isProcessing = false
                case .pending:
                    isProcessing = false
                @unknown default:
                    isProcessing = false
                }
            } catch {
#if DEBUG
                await recordMembership(tier: tier)
                isProcessing = false
                showSuccess = true
                HapticManager.shared.successPattern()
#else
                isProcessing = false
                errorMessage = "Purchase failed. Please try again."
                showError = true
#endif
            }
        }
    }

    private func recordMembership(tier: MembershipTier) async {
        #if canImport(FirebaseFirestore)
        let uid = AppState.shared.currentUser?.id ?? ""
        guard !uid.isEmpty else { return }
        let data: [String: Any] = [
            "userId": uid,
            "channelId": channelId,
            "tierId": tier.id,
            "tierName": tier.name,
            "joinedAt": FieldValue.serverTimestamp(),
            "status": "active"
        ]
        try? await Firestore.firestore()
            .collection("channel-memberships")
            .document("\(channelId)_\(uid)")
            .setData(data)
        #endif
    }
}

#Preview {
    ChannelMembershipView(
        channelId: "creator123",
        channelName: "Shot By Keonta",
        channelAvatarURL: nil
    )
}
