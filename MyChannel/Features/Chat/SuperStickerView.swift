//
//  SuperStickerView.swift
//  MyChannel
//
//  Super Stickers: one-tap emoji packs purchasable via StoreKit 2.
//  Sending a sticker posts a live chat message with .superSticker type.
//

import SwiftUI
import StoreKit

// MARK: - Sticker Definition

struct SuperSticker: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let productId: String
    let color: Color
}

extension SuperSticker {
    static let catalog: [SuperSticker] = [
        SuperSticker(id: "wave",     emoji: "👋", name: "Wave",     productId: "com.mychannel.supersticker.wave",     color: .blue),
        SuperSticker(id: "fire",     emoji: "🔥", name: "Fire",     productId: "com.mychannel.supersticker.fire",     color: .orange),
        SuperSticker(id: "heart",    emoji: "❤️", name: "Heart",    productId: "com.mychannel.supersticker.heart",    color: .red),
        SuperSticker(id: "trophy",   emoji: "🏆", name: "Trophy",   productId: "com.mychannel.supersticker.trophy",   color: .yellow),
        SuperSticker(id: "confetti", emoji: "🎉", name: "Confetti", productId: "com.mychannel.supersticker.confetti", color: .purple),
    ]
}

// MARK: - View

@MainActor
struct SuperStickerView<Service: LiveChatServiceProtocol & ObservableObject>: View {
    let streamId: String
    @ObservedObject var chatService: Service

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSticker: SuperSticker? = nil
    @State private var isPurchasing = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Send a Super Sticker to support the creator!")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(SuperSticker.catalog) { sticker in
                        stickerCard(sticker)
                    }
                }
                .padding(.horizontal, 24)

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                if let selected = selectedSticker {
                    Button {
                        Task { await purchase(selected) }
                    } label: {
                        HStack {
                            if isPurchasing { ProgressView().tint(.white) }
                            else { Text("Send \(selected.emoji) \(selected.name) Sticker") }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selected.color)
                        .foregroundColor(.white)
                        .font(.headline)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Super Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Sticker Sent! \(selectedSticker?.emoji ?? "")", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your sticker was sent to the chat.")
            }
        }
    }

    // MARK: - Sticker card
    private func stickerCard(_ sticker: SuperSticker) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSticker = sticker
            }
            HapticManager.shared.impact(style: .light)
        } label: {
            VStack(spacing: 8) {
                Text(sticker.emoji)
                    .font(.system(size: 44))
                Text(sticker.name)
                    .font(.caption.bold())
                    .foregroundColor(selectedSticker?.id == sticker.id ? .white : AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedSticker?.id == sticker.id ? sticker.color : AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(sticker.color.opacity(selectedSticker?.id == sticker.id ? 0 : 0.3), lineWidth: 1.5)
                    )
            )
            .scaleEffect(selectedSticker?.id == sticker.id ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase
    private func purchase(_ sticker: SuperSticker) async {
        isPurchasing = true
        errorMessage = nil
        do {
            let products = try await Product.products(for: [sticker.productId])
            guard let product = products.first else {
#if DEBUG
                await sendStickerMessage(sticker)
                isPurchasing = false
                showSuccess = true
#else
                errorMessage = "Sticker not available. Please try again later."
                isPurchasing = false
#endif
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await sendStickerMessage(sticker)
                    await tx.finish()
                    isPurchasing = false
                    showSuccess = true
                } else {
                    isPurchasing = false
                }
            case .userCancelled:
                isPurchasing = false
            case .pending:
                isPurchasing = false
            @unknown default:
                isPurchasing = false
            }
        } catch {
#if DEBUG
            await sendStickerMessage(sticker)
            isPurchasing = false
            showSuccess = true
#else
            errorMessage = error.localizedDescription
            isPurchasing = false
#endif
        }
    }

    private func sendStickerMessage(_ sticker: SuperSticker) async {
        let msg = LiveChatMessage(
            streamId: streamId,
            userId: AppState.shared.currentUser?.id ?? "",
            username: AppState.shared.currentUser?.displayName ?? "Viewer",
            content: "\(sticker.emoji) Super Sticker: \(sticker.name)",
            messageType: .superChat,
            superChatAmount: 0.99
        )
        try? await chatService.sendMessage(msg)
    }
}

#Preview {
    SuperStickerView(streamId: "preview-stream", chatService: MockLiveChatService())
}
