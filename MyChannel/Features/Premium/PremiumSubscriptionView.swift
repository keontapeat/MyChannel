//
//  PremiumSubscriptionView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct PremiumSubscriptionView: View {
    @StateObject private var premiumService = PremiumService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTier: PremiumTier = .pro
    @State private var isYearly: Bool = false
    @State private var showingCheckout: Bool = false
    @State private var isSubscribing: Bool = false
    @State private var selectedFeatures: Set<PremiumFeature> = []
    @State private var animateFeatures: Bool = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Premium gradient background
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.background,
                            AppTheme.Colors.primary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Hero Section
                            premiumHeroSection
                                .padding(.top, 20)
                            
                            // Tier Selection
                            tierSelectionSection
                                .padding(.vertical, 30)
                            
                            // Features Showcase
                            featuresSection
                                .padding(.vertical, 20)
                            
                            // Comparison Table
                            comparisonSection
                                .padding(.vertical, 30)
                            
                            // CTA Section
                            ctaSection
                                .padding(.vertical, 40)
                                .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("MyChannel Premium")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                animateFeatures = true
            }
        }
        .sheet(isPresented: $showingCheckout) {
            PremiumCheckoutView(tier: selectedTier, isYearly: isYearly)
        }
    }
    
    // MARK: - Hero Section
    private var premiumHeroSection: some View {
        VStack(spacing: 24) {
            // Premium Logo Animation
            ZStack {
                Circle()
                    .fill(selectedTier.gradient)
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: AppTheme.Colors.primary.opacity(0.4),
                        radius: 20,
                        x: 0,
                        y: 8
                    )
                    .scaleEffect(animateFeatures ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateFeatures)
                
                Image(systemName: selectedTier.icon)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .rotationEffect(.degrees(animateFeatures ? 360 : 0))
                    .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animateFeatures)
            }
            
            VStack(spacing: 8) {
                Text("Unlock the Ultimate")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("MyChannel Experience")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedTier.gradient)
                    .multilineTextAlignment(.center)
                
                Text("Join millions of creators enjoying premium features that YouTube Premium wishes they had!")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tier Selection
    private var tierSelectionSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Choose Your Power Level")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Billing Toggle
            HStack(spacing: 16) {
                Text("Monthly")
                    .font(.system(size: 16, weight: isYearly ? .medium : .bold))
                    .foregroundColor(isYearly ? AppTheme.Colors.textSecondary : AppTheme.Colors.primary)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isYearly.toggle()
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    ZStack {
                        Capsule()
                            .fill(isYearly ? AnyShapeStyle(selectedTier.gradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                            .frame(width: 60, height: 32)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                            .offset(x: isYearly ? 14 : -14)
                            .shadow(radius: 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Annual")
                        .font(.system(size: 16, weight: isYearly ? .bold : .medium))
                        .foregroundColor(isYearly ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    
                    if isYearly {
                        Text("Save 20%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Tier Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(PremiumTier.allCases.filter { $0 != .none }, id: \.self) { tier in
                        PremiumTierCard(
                            tier: tier,
                            isSelected: selectedTier == tier,
                            isYearly: isYearly,
                            onSelect: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedTier = tier
                                    selectedFeatures = Set(tier.features)
                                }
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("What You Get")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Array(selectedFeatures.enumerated()), id: \.element) { index, feature in
                    PremiumFeatureCard(feature: feature)
                        .scaleEffect(animateFeatures ? 1.0 : 0.8)
                        .opacity(animateFeatures ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: animateFeatures
                        )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Comparison Section
    private var comparisonSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Why MyChannel Premium?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ComparisonRow(
                    feature: "Ad-Free Experience",
                    myChannel: "✅ Zero ads, ever",
                    youtube: "❌ Still shows some ads",
                    advantage: true
                )
                
                ComparisonRow(
                    feature: "Download Quality",
                    myChannel: "✅ Up to 4K downloads",
                    youtube: "❌ Max 1080p",
                    advantage: true
                )
                
                ComparisonRow(
                    feature: "AI Recommendations",
                    myChannel: "✅ Smart AI playlists",
                    youtube: "❌ Basic recommendations",
                    advantage: true
                )
                
                ComparisonRow(
                    feature: "Creator Tools",
                    myChannel: "✅ Professional studio",
                    youtube: "❌ Limited tools",
                    advantage: true
                )
                
                ComparisonRow(
                    feature: "Spatial Audio",
                    myChannel: "✅ Immersive 3D sound",
                    youtube: "❌ Standard audio only",
                    advantage: true
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - CTA Section
    private var ctaSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Ready to Level Up?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Join the premium experience today!")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Button(action: {
                showingCheckout = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: selectedTier.icon)
                        .font(.system(size: 20, weight: .bold))
                    
                    VStack(spacing: 4) {
                        Text("Start \(selectedTier.title)")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text(isYearly ? selectedTier.annualPrice : selectedTier.price)
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(selectedTier.gradient)
                .cornerRadius(25)
                .shadow(
                    color: AppTheme.Colors.primary.opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .scaleEffect(isSubscribing ? 0.95 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSubscribing)
            
            VStack(spacing: 8) {
                Text("• Cancel anytime • No hidden fees • 7-day free trial")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                Text("Trusted by 10M+ creators worldwide")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selectedTier.gradient)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Premium Tier Card
struct PremiumTierCard: View {
    let tier: PremiumTier
    let isSelected: Bool
    let isYearly: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                // Tier Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(tier.gradient)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: tier.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(tier.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    VStack(spacing: 4) {
                        Text(isYearly ? tier.annualPrice : tier.price)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(tier.gradient)
                        
                        if isYearly {
                            Text("Save 20%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Features List
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features.prefix(4), id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            
                            Text(feature.title)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    if tier.features.count > 4 {
                        Text("+ \(tier.features.count - 4) more features")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(tier.gradient)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .frame(width: 200, height: 280)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? AnyShapeStyle(tier.gradient) : AnyShapeStyle(Color.clear),
                                lineWidth: 3
                            )
                    )
                    .shadow(
                        color: isSelected ? AppTheme.Colors.primary.opacity(0.3) : AppTheme.Colors.textPrimary.opacity(0.1),
                        radius: isSelected ? 15 : 8,
                        x: 0,
                        y: isSelected ? 8 : 4
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Feature Card
struct PremiumFeatureCard: View {
    let feature: PremiumFeature
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(feature.color)
            }
            
            VStack(spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(feature.description)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(16)
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

// MARK: - Comparison Row
struct ComparisonRow: View {
    let feature: String
    let myChannel: String
    let youtube: String
    let advantage: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(feature)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MyChannel")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text(myChannel)
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("YouTube Premium")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Text(youtube)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(advantage ? Color.green.opacity(0.1) : AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(advantage ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

#Preview {
    PremiumSubscriptionView()
}