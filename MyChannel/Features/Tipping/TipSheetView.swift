//
//  TipSheetView.swift
//  MyChannel
//
//  IAP-compliant tipping UI (Apple Guideline 3.1.1).
//  Viewers purchase tip credits, then send them to creators.
//

import SwiftUI
import StoreKit

struct TipSheetView: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TipStoreKitService.shared
    @State private var selectedProduct: Product?
    @State private var tipMessage = ""
    @State private var isPurchasing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    creatorHeader
                    
                    if store.isLoading {
                        ProgressView("Loading tip options...")
                            .padding(40)
                    } else if store.products.isEmpty {
                        emptyState
                    } else {
                        tipProductGrid
                        messageSection
                        purchaseButton
                    }
                    
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    
                    complianceNote
                }
                .padding(20)
            }
            .navigationTitle("Send a Tip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if store.products.isEmpty {
                    await store.loadProducts()
                }
            }
            .alert("Tip Sent! 🎉", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your tip has been sent to \(creator.displayName). They'll receive a notification!")
            }
        }
    }
    
    // MARK: - Creator Header
    
    private var creatorHeader: some View {
        VStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            Text("Tip \(creator.displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Show your support with a tip")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Tip Product Grid
    
    private var tipProductGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an amount")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    tipProductCard(product)
                }
            }
        }
    }
    
    private func tipProductCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let credits = TipProductID(rawValue: product.id)?.credits ?? 0
        
        return Button(action: { selectedProduct = product }) {
            VStack(spacing: 8) {
                Text("$\(product.displayPrice)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                
                Text("\(credits) credit\(credits == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a message (optional)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            TextField("Say something nice...", text: $tipMessage, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(AppTheme.Colors.surface)
                .cornerRadius(10)
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button(action: { Task { await sendTip() } }) {
            HStack(spacing: 10) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "heart.fill")
                }
                Text(isPurchasing ? "Processing..." : "Send Tip")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedProduct == nil ? Color.gray : AppTheme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(selectedProduct == nil || isPurchasing)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Tip products unavailable")
                .font(.system(size: 16, weight: .semibold))
            Text("Please try again later or contact support.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.red)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Compliance Note
    
    private var complianceNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .font(.system(size: 14))
                Text("Tips are processed through Apple's In-App Purchase system. The creator receives 63% of the tip amount after Apple's 30% fee and MyChannel's 7% platform fee.")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    
    private func sendTip() async {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        
        do {
            _ = try await store.purchase(
                product,
                for: creator.id,
                message: tipMessage.isEmpty ? nil : tipMessage
            )
            
            HapticManager.shared.successPattern()
            showSuccess = true
            
        } catch TipStoreError.userCancelled {
            // User cancelled — no error message needed
            return
            
        } catch {
            HapticManager.shared.errorPattern()
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Product Display Price Extension

extension Product {
    var displayPrice: String {
        return price.formatted(.currency(code: priceFormatStyle.currencyCode))
    }
}

#Preview {
    TipSheetView(creator: User(
        id: "creator123",
        username: "johndoe",
        displayName: "John Doe",
        email: "john@example.com",
        profileImageURL: nil,
        bio: nil,
        subscriberCount: 1_500_000,
        videoCount: 250,
        isVerified: true,
        createdAt: Date()
    ))
}
