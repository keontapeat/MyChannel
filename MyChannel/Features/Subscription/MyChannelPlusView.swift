//
//  MyChannelPlusView.swift
//  MyChannel
//
//  🌟 MYCHANNEL PLUS+ PREMIUM SUBSCRIPTION
//  Sleek, modern, clean design - NO gradients!
//  Full parity with YouTube Premium features
//

import SwiftUI
import StoreKit

struct MyChannelPlusView: View {
    @StateObject private var storeKit = StoreKitService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var showingPurchaseSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isPurchasing = false
    
    var body: some View {
        ZStack {
            // Clean white/dark background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            if !AppConfig.Features.enableSubscriptions {
                // 🔥 FIX 2.1(b): Show Coming Soon when IAPs not yet submitted
                comingSoonView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        header
                        
                        // Benefits Grid
                        benefitsGrid
                            .padding(.top, 40)
                        
                        // Pricing Plans
                        pricingPlans
                            .padding(.top, 50)
                        
                        // Subscribe Button
                        subscribeButton
                            .padding(.top, 30)
                        
                        // Features Comparison
                        featuresComparison
                            .padding(.top, 50)
                        
                        // Footer
                        footer
                            .padding(.top, 40)
                            .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
        .alert("Subscription Active!", isPresented: $showingPurchaseSuccess) {
            Button("Let's Go!") {
                dismiss()
            }
        } message: {
            Text("Welcome to MyChannel Plus+! Enjoy ad-free videos and offline downloads.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .task {
            guard AppConfig.Features.enableSubscriptions else { return }
            // Pre-load products so purchase button works immediately
            if storeKit.products.isEmpty {
                await storeKit.loadProducts()
            }
        }
    }
    
    // MARK: - Coming Soon (when IAPs are not yet submitted)
    
    private var comingSoonView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("MyChannel Plus+")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Coming Soon")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("Ad-free videos, offline downloads, background play, and more. Stay tuned!")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Benefits preview
            benefitsGrid
                .padding(.top, 10)
                .padding(.horizontal, 20)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            // Plus+ Logo
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 80)
            
            // Title
            Text("MyChannel")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Plus+")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
            
            // Subtitle
            Text("Ad-free videos, offline downloads, and more")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Benefits Grid
    
    private var benefitsGrid: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                benefitCard(
                    icon: "play.slash.fill",
                    title: "Ad-Free",
                    description: "Watch videos without interruptions"
                )
                
                benefitCard(
                    icon: "arrow.down.circle.fill",
                    title: "Downloads",
                    description: "Save videos for offline viewing"
                )
            }
            
            HStack(spacing: 15) {
                benefitCard(
                    icon: "play.fill",
                    title: "Background Play",
                    description: "Listen with screen off or minimized"
                )
                
                benefitCard(
                    icon: "star.fill",
                    title: "Early Access",
                    description: "Try new features before everyone"
                )
            }
        }
    }
    
    private func benefitCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.black)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Pricing Plans
    
    private var pricingPlans: some View {
        VStack(spacing: 12) {
            Text("Choose your plan")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Monthly Plan
                PlanCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    price: "$4.99",
                    period: "month",
                    savings: nil
                ) {
                    selectedPlan = .monthly
                }
                
                // Annual Plan
                PlanCard(
                    plan: .annual,
                    isSelected: selectedPlan == .annual,
                    price: "$49.99",
                    period: "year",
                    savings: "Save 17%"
                ) {
                    selectedPlan = .annual
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Subscribe Button
    
    private var subscribeButton: some View {
        VStack(spacing: 12) {
            Button {
                subscribeToPlan()
            } label: {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Start Free Trial")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .cornerRadius(28)
            }
            .disabled(isPurchasing)
            
            VStack(spacing: 4) {
                Text("7 days free, then \(selectedPlan.priceText)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text("Cancel anytime")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Features Comparison
    
    private var featuresComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("All MyChannel Plus+ Features")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                featureRow(icon: "play.slash.fill", title: "Ad-free videos", description: "No ads before, during, or after videos")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "arrow.down.circle.fill", title: "Offline downloads", description: "Download videos to watch anywhere")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "play.fill", title: "Background play", description: "Keep videos playing when you switch apps")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "pip.fill", title: "Picture-in-picture", description: "Watch videos while using other apps")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "star.fill", title: "Early access features", description: "Try new features before everyone else")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "crown.fill", title: "Premium badge", description: "Show your support with a Plus+ badge")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "gauge.high", title: "Higher video quality", description: "Stream videos in best available quality")
                Divider().padding(.leading, 50)
                
                featureRow(icon: "bolt.fill", title: "Priority support", description: "Get help from our team faster")
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.black)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        VStack(spacing: 16) {
            // Restore Purchases (required by Apple)
            Button {
                Task {
                    isPurchasing = true
                    await storeKit.restore()
                    isPurchasing = false
                    if storeKit.isPremium {
                        showingPurchaseSuccess = true
                        HapticManager.shared.successPattern()
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
            }
            
            Text("By subscribing, you agree to our Terms of Service and acknowledge our Privacy Policy. Free trial available for new subscribers only. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    if let url = URL(string: "https://mychannel.live/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://mychannel.live/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func subscribeToPlan() {
        isPurchasing = true
        
        Task {
            do {
                let success = try await storeKit.purchase(plan: selectedPlan)
                await MainActor.run {
                    isPurchasing = false
                    if success {
                        showingPurchaseSuccess = true
                        HapticManager.shared.successPattern()
                    } else {
                        errorMessage = "Purchase was cancelled"
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    HapticManager.shared.errorPattern()
                }
            }
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let price: String
    let period: String
    let savings: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Radio Button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.black : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // Plan Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(plan == .annual ? "Best value" : "Flexible option")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("per \(period)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Plan

enum SubscriptionPlan: String, CaseIterable {
    case monthly = "monthly"
    case annual = "annual"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }
    
    var priceText: String {
        switch self {
        case .monthly: return "$4.99/month"
        case .annual: return "$49.99/year"
        }
    }
    
    var productID: String {
        switch self {
        case .monthly: return "com.mychannel.plus.monthly"
        case .annual: return "com.mychannel.plus.annual"
        }
    }
}

// MARK: - Preview

#Preview {
    MyChannelPlusView()
}

