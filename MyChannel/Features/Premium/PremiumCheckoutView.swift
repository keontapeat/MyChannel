//
//  PremiumCheckoutView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct PremiumCheckoutView: View {
    let tier: PremiumTier
    let isYearly: Bool
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premiumService = PremiumService.shared
    @State private var isProcessing = false
    @State private var showingSuccess = false
    @State private var animateSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                tier.gradient.opacity(0.1)
                    .ignoresSafeArea()
                
                if showingSuccess {
                    successView
                } else {
                    checkoutView
                }
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    private var checkoutView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Order Summary
                orderSummarySection
                
                // Payment Method
                paymentMethodSection
                
                // Terms and Subscribe
                subscribeSection
            }
            .padding(20)
        }
    }
    
    private var orderSummarySection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Order Summary")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Tier Info
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(tier.gradient)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: tier.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(isYearly ? "Annual Subscription" : "Monthly Subscription")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isYearly ? tier.annualPrice : tier.price)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(tier.gradient)
                        
                        if isYearly {
                            Text("Save 20%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if !tier.features.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Included Features:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        ForEach(tier.features.prefix(6), id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                
                                Text(feature.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        
                        if tier.features.count > 6 {
                            Text("+ \(tier.features.count - 6) more premium features")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(tier.gradient)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.cardBackground)
                    .shadow(
                        color: AppTheme.Colors.textPrimary.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
        }
    }
    
    private var paymentMethodSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Payment Method")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                PaymentMethodRow(
                    icon: "creditcard.fill",
                    title: "Apple Pay",
                    subtitle: "Pay with Face ID or Touch ID",
                    color: .black,
                    isSelected: true
                )
                
                PaymentMethodRow(
                    icon: "creditcard.fill",
                    title: "Credit Card",
                    subtitle: "Visa, MasterCard, American Express",
                    color: .blue,
                    isSelected: false
                )
                
                PaymentMethodRow(
                    icon: "paypal",
                    title: "PayPal",
                    subtitle: "Pay with your PayPal account",
                    color: Color(red: 0.0, green: 0.48, blue: 0.75),
                    isSelected: false
                )
            }
        }
    }
    
    private var subscribeSection: some View {
        VStack(spacing: 24) {
            // Subscribe Button
            Button(action: subscribe) {
                HStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: tier.icon)
                            .font(.system(size: 18, weight: .bold))
                    }
                    
                    Text(isProcessing ? "Processing..." : "Subscribe Now")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if isProcessing {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.gray)
                        } else {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(tier.gradient)
                        }
                    }
                )
                .shadow(
                    color: isProcessing ? .clear : AppTheme.Colors.primary.opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .scaleEffect(isProcessing ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isProcessing)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
            
            // Terms
            VStack(spacing: 12) {
                Text("7-day free trial • Cancel anytime")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success Animation
            ZStack {
                Circle()
                    .fill(tier.gradient)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateSuccess ? 1.0 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateSuccess)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(animateSuccess ? 1.0 : 0.5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateSuccess)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to Premium!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(tier.gradient)
                    .multilineTextAlignment(.center)
                
                Text("You're now subscribed to \(tier.title)")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text("Start enjoying all premium features right now!")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .opacity(animateSuccess ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.5).delay(0.4), value: animateSuccess)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Start Exploring")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(tier.gradient)
                    .cornerRadius(25)
                    .shadow(
                        color: AppTheme.Colors.primary.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(animateSuccess ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.5).delay(0.6), value: animateSuccess)
            
            Spacer()
        }
        .padding(20)
        .onAppear {
            withAnimation {
                animateSuccess = true
            }
        }
    }
    
    private func subscribe() {
        isProcessing = true
        
        Task {
            do {
                try await premiumService.subscribe(to: tier)
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isProcessing = false
                        showingSuccess = true
                    }
                }
                
                // Auto dismiss after showing success
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Payment Method Row
struct PaymentMethodRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .green : AppTheme.Colors.textTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    PremiumCheckoutView(tier: .pro, isYearly: false)
}