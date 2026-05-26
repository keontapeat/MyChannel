//
//  YouTubePremiumUpsellSheet.swift
//  MyChannel
//
//  🔥 YOUTUBE PREMIUM-STYLE UPSELL MODAL
//  Exact replica of YouTube's Premium upsell UI
//
//  Created by Keonta on 11/30/25.
//

import SwiftUI
import StoreKit

// MARK: - 🔥 YouTube Premium-Style Upsell Sheet
struct YouTubePremiumUpsellSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    @StateObject private var premiumService = PremiumService.shared
    
    @State private var isLoading = false
    @State private var showConfetti = false
    @State private var selectedPlan: PlanType = .monthly
    
    enum PlanType {
        case monthly
        case annual
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            dragIndicator
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Logo & Title
                    premiumHeader
                    
                    // Main headline
                    headlineSection
                    
                    // Benefits list
                    benefitsList
                    
                    // Plan selector (optional)
                    // planSelector
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            
            // Bottom action buttons
            if AppConfig.Features.enableSubscriptions {
                actionButtons
            } else {
                // 🔥 FIX 2.1(b): Hide purchase buttons when IAPs not submitted
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .cornerRadius(26)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(AppTheme.Colors.background)
        .overlay {
            if showConfetti {
                PremiumConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .task {
            await store.loadProducts()
        }
    }
    
    // MARK: - Drag Indicator
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.gray.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
    
    // MARK: - Premium Header (Logo + Premium text)
    private var premiumHeader: some View {
        HStack(spacing: 8) {
            // MC Logo (actual app logo asset)
            Image("MyChannel")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text("Premium")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Headline Section
    private var headlineSection: some View {
        VStack(spacing: 8) {
            Text("Watch uninterrupted with Premium")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("$13.99/month • Cancel anytime")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Benefits List
    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 20) {
            YouTubePremiumBenefitRow(
                icon: "checkmark",
                text: "Ad-free MyChannel and MyChannel Music"
            )
            
            YouTubePremiumBenefitRow(
                icon: "checkmark",
                text: "Download videos to watch offline"
            )
            
            YouTubePremiumBenefitRow(
                icon: "checkmark",
                text: "Play videos in the background"
            )
        }
        .padding(.top, 8)
    }
    
    // MARK: - Plan Selector (Optional - for showing monthly vs annual)
    private var planSelector: some View {
        VStack(spacing: 12) {
            // Monthly plan
            PlanOptionRow(
                title: "Monthly",
                price: "$13.99/month",
                isSelected: selectedPlan == .monthly,
                isBestValue: false
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedPlan = .monthly
                }
                HapticManager.shared.impact(style: .light)
            }
            
            // Annual plan
            PlanOptionRow(
                title: "Annual",
                price: "$139.99/year",
                subtitle: "Save $27.89",
                isSelected: selectedPlan == .annual,
                isBestValue: true
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedPlan = .annual
                }
                HapticManager.shared.impact(style: .light)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Divider
            Rectangle()
                .fill(AppTheme.Colors.surface)
                .frame(height: 1)
            
            HStack(spacing: 16) {
                // Not now button
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    dismiss()
                }) {
                    Text("Not now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                
                // Get Premium button
                Button(action: {
                    Task {
                        await purchasePremium()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Text("Get MyChannel Premium")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                    )
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Purchase Action
    private func purchasePremium() async {
        isLoading = true
        HapticManager.shared.impact(style: .medium)
        
        do {
            // Try to find the premium product
            if let premiumProduct = store.products.first(where: { $0.id.contains("premium") || $0.id.contains("pro") }) {
                let result = await store.purchase(premiumProduct)
                
                if result {
                    // Success!
                    showConfetti = true
                    HapticManager.shared.notification(type: .success)
                    
                    // Update premium service
                    try await premiumService.subscribe(to: .pro)
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        dismiss()
                    }
                }
            } else {
                // Fallback: simulate subscription for demo
                try await Task.sleep(nanoseconds: 1_500_000_000)
                try await premiumService.subscribe(to: .pro)
                
                showConfetti = true
                HapticManager.shared.notification(type: .success)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            }
        } catch {
            HapticManager.shared.notification(type: .error)
            print("❌ Premium purchase failed: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - YouTube Premium Benefit Row
struct YouTubePremiumBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Checkmark icon (YouTube style - filled circle with check)
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.textPrimary)
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Colors.background)
            }
            
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Plan Option Row
struct PlanOptionRow: View {
    let title: String
    let price: String
    var subtitle: String? = nil
    let isSelected: Bool
    var isBestValue: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Text(price)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Confetti View
struct PremiumConfettiView: View {
    @State private var particles: [PremiumConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles(in: geometry.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        
        particles = (0..<50).map { _ in
            PremiumConfettiParticle(
                id: UUID(),
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: -20),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                opacity: 1.0
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        for i in particles.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 1.5...2.5)
            
            withAnimation(.easeOut(duration: duration).delay(delay)) {
                particles[i].position = CGPoint(
                    x: particles[i].position.x + CGFloat.random(in: -100...100),
                    y: size.height + 50
                )
                particles[i].opacity = 0
            }
        }
    }
}

struct PremiumConfettiParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
}

// MARK: - Stop Ads Upsell (Specific variant for "Stop ads" button)
struct StopAdsUpsellSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    @StateObject private var premiumService = PremiumService.shared
    
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.top, 8)
                    
                    // Title
                    Text("Stop seeing ads")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    // Subtitle
                    Text("Get MyChannel Premium for an uninterrupted experience")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        StopAdsBenefitRow(icon: "play.slash.fill", text: "No ads before, during, or after videos")
                        StopAdsBenefitRow(icon: "arrow.down.circle.fill", text: "Download videos to watch offline")
                        StopAdsBenefitRow(icon: "iphone.badge.play", text: "Play in background while using other apps")
                        StopAdsBenefitRow(icon: "music.note", text: "Access to MyChannel Music Premium")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Price
                    VStack(spacing: 4) {
                        Text("Starting at $13.99/month")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Cancel anytime")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, 16)
                    
                    Spacer(minLength: 20)
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        isLoading = true
                        try? await premiumService.subscribe(to: .pro)
                        HapticManager.shared.notification(type: .success)
                        isLoading = false
                        dismiss()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Get Premium")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                    )
                }
                
                Button(action: { dismiss() }) {
                    Text("No thanks")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background)
    }
}

struct StopAdsBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 28)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview("Premium Upsell") {
    YouTubePremiumUpsellSheet()
        .preferredColorScheme(.light)
}

#Preview("Stop Ads Upsell") {
    StopAdsUpsellSheet()
        .preferredColorScheme(.dark)
}


