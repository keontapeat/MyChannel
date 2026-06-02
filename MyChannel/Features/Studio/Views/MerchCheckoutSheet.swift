//
//  MerchCheckoutSheet.swift
//  MyChannel
//
//  Buyer checkout for PHYSICAL creator merchandise (ships to the buyer's
//  address). Charges via Stripe — NOT Apple IAP — per Apple Guideline 3.1.3(e)
//  for physical goods. Collects a shipping address, creates the order through
//  the authenticated backend, then confirms via the Stripe PaymentSheet.
//

import SwiftUI

struct MerchCheckoutSheet: View {
    let product: CreatorProduct
    var onComplete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var checkout = MerchCheckoutService.shared

    @State private var quantity = 1
    @State private var shipping = MerchShippingAddress()
    @State private var isPlacingOrder = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private let shippingFlatCents = 599

    private var subtotalCents: Int { Int((product.price * 100).rounded()) * quantity }
    private var totalCents: Int { subtotalCents + shippingFlatCents }

    var body: some View {
        NavigationStack {
            Form {
                productSection
                quantitySection
                shippingSection
                totalsSection

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task { await placeOrder() }
                    } label: {
                        HStack {
                            if isPlacingOrder { ProgressView().padding(.trailing, 4) }
                            Text(isPlacingOrder ? "Processing…" : "Pay \(formatted(totalCents))")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!shipping.isComplete || isPlacingOrder || product.stock < quantity)
                } footer: {
                    Text("Physical item — ships to your address. Payments are processed securely by Stripe, not through the App Store.")
                        .font(.system(size: 12))
                }
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Order placed 🎉", isPresented: $didSucceed) {
                Button("Done") {
                    onComplete()
                    dismiss()
                }
            } message: {
                Text("Your order is confirmed. You'll get shipping updates as \(product.name) is on its way.")
            }
        }
    }

    private var productSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: product.imageSystemName)
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                    .frame(width: 56, height: 56)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name).font(.system(size: 16, weight: .semibold))
                    Text(product.category).font(.system(size: 13)).foregroundColor(.secondary)
                    Text(formatted(Int((product.price * 100).rounded()))).font(.system(size: 14, weight: .semibold)).foregroundColor(.green)
                }
                Spacer()
            }
        }
    }

    private var quantitySection: some View {
        Section("Quantity") {
            Stepper(value: $quantity, in: 1...min(max(product.stock, 1), 25)) {
                Text("\(quantity)")
            }
            if product.stock <= 5 {
                Text("Only \(product.stock) left in stock")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
        }
    }

    private var shippingSection: some View {
        Section("Shipping Address") {
            TextField("Address line 1", text: $shipping.line1)
                .textContentType(.streetAddressLine1)
            TextField("Address line 2 (optional)", text: $shipping.line2)
                .textContentType(.streetAddressLine2)
            TextField("City", text: $shipping.city)
                .textContentType(.addressCity)
            TextField("State / Province", text: $shipping.state)
                .textContentType(.addressState)
            TextField("ZIP / Postal code", text: $shipping.postalCode)
                .textContentType(.postalCode)
            TextField("Country code (e.g. US)", text: $shipping.country)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }

    private var totalsSection: some View {
        Section("Order Summary") {
            row("Subtotal", formatted(subtotalCents))
            row("Shipping", formatted(shippingFlatCents))
            HStack {
                Text("Total").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(formatted(totalCents)).font(.system(size: 15, weight: .bold))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.system(size: 14))
    }

    private func placeOrder() async {
        isPlacingOrder = true
        errorMessage = nil
        do {
            let order = try await checkout.createOrder(
                productId: product.id,
                quantity: quantity,
                shipping: shipping
            )
            let paid = try await checkout.confirmPayment(clientSecret: order.clientSecret)
            await MainActor.run {
                isPlacingOrder = false
                if paid {
                    HapticManager.shared.notification(type: .success)
                    didSucceed = true
                } else {
                    errorMessage = "Payment was canceled."
                }
            }
        } catch {
            await MainActor.run {
                isPlacingOrder = false
                errorMessage = error.localizedDescription
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    private func formatted(_ cents: Int) -> String {
        String(format: "$%.2f", Double(cents) / 100.0)
    }
}
