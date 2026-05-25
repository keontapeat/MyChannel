//
//  Day1MonetizationOnboarding.swift
//  MyChannel
//
//  🔥💰 DAY 1 MONETIZATION - START EARNING IMMEDIATELY! 💰🔥
//
//  No waiting! No requirements! Just upload and earn!
//
//  VS YouTube:
//  ❌ YouTube: 1,000 subscribers required
//  ❌ YouTube: 4,000 watch hours required
//  ❌ YouTube: 30+ day waiting for first payout
//  ❌ YouTube: $100 minimum payout
//  ❌ YouTube: 55% revenue share (45% to Google!)
//
//  ✅ MyChannel: 0 subscribers required
//  ✅ MyChannel: 0 watch hours required
//  ✅ MyChannel: 24-hour payouts
//  ✅ MyChannel: NO minimum payout
//  ✅ MyChannel: 90% revenue share!
//

import SwiftUI

// MARK: - 🔥 DAY 1 MONETIZATION ONBOARDING

struct Day1MonetizationOnboarding: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var isEnabling = false
    @State private var isEnabled = false
    @State private var animateChecks = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.1),
                    Color.black,
                    Color(red: 0.05, green: 0.1, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Money particles animation
            MoneyParticlesView()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                }
                
                TabView(selection: $currentStep) {
                    step1View.tag(0)
                    step2View.tag(1)
                    step3View.tag(2)
                    step4View.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 && currentStep < 3 {
                        Button {
                            withAnimation { currentStep -= 1 }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Button {
                        if currentStep < 3 {
                            withAnimation { currentStep += 1 }
                            HapticManager.shared.impact(style: .medium)
                        } else {
                            enableMonetization()
                        }
                    } label: {
                        HStack {
                            if currentStep == 3 {
                                if isEnabling {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else if isEnabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                }
                            }
                            
                            Text(buttonText)
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isEnabling)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Step indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.green : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Step 1: Hero
    
    private var step1View: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated money icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateChecks ? 1.2 : 1.0)
                    .opacity(animateChecks ? 0.5 : 1)
                    .animation(.easeInOut(duration: 1.5).repeatForever(), value: animateChecks)
                
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 100, height: 100)
                
                Text("💰")
                    .font(.system(size: 60))
            }
            .onAppear { animateChecks = true }
            
            VStack(spacing: 16) {
                Text("Start Earning")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("FROM DAY 1")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("No subscribers needed. No waiting.\nJust upload and earn.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 2: Comparison
    
    private var step2View: some View {
        VStack(spacing: 24) {
            Text("🚀 MyChannel vs YouTube")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 32)
            
            VStack(spacing: 16) {
                MonetizationComparisonRow(
                    feature: "Subscribers Required",
                    youtube: "1,000",
                    mychannel: "0",
                    isAnimated: animateChecks
                )
                
                MonetizationComparisonRow(
                    feature: "Watch Hours Required",
                    youtube: "4,000",
                    mychannel: "0",
                    isAnimated: animateChecks
                )
                
                MonetizationComparisonRow(
                    feature: "Revenue Share",
                    youtube: "55%",
                    mychannel: "90%",
                    isAnimated: animateChecks,
                    myChannelHighlight: true
                )
                
                MonetizationComparisonRow(
                    feature: "First Payout",
                    youtube: "30+ days",
                    mychannel: "24 hours",
                    isAnimated: animateChecks,
                    myChannelHighlight: true
                )
                
                MonetizationComparisonRow(
                    feature: "Minimum Payout",
                    youtube: "$100",
                    mychannel: "$0",
                    isAnimated: animateChecks,
                    myChannelHighlight: true
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: How It Works
    
    private var step3View: some View {
        VStack(spacing: 24) {
            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 32)
            
            VStack(spacing: 20) {
                HowItWorksRow(
                    step: 1,
                    icon: "arrow.up.circle.fill",
                    title: "Upload Your Video",
                    description: "Any length, any content"
                )
                
                HowItWorksRow(
                    step: 2,
                    icon: "dollarsign.circle.fill",
                    title: "Monetization Enabled",
                    description: "Automatically - no waiting!"
                )
                
                HowItWorksRow(
                    step: 3,
                    icon: "play.circle.fill",
                    title: "Real Ads Play",
                    description: "From Google, SpotX & more"
                )
                
                HowItWorksRow(
                    step: 4,
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    title: "Watch Money Grow",
                    description: "Real-time earnings tracker"
                )
                
                HowItWorksRow(
                    step: 5,
                    icon: "banknote.fill",
                    title: "Get Paid Fast",
                    description: "24-hour payouts to your bank"
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Step 4: Enable
    
    private var step4View: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if isEnabled {
                // Success state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                    }
                    
                    Text("🎉 You're Ready to Earn!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your next video will start earning\nmoney from the very first view!")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            } else {
                // Ready to enable
                VStack(spacing: 24) {
                    Text("🔥")
                        .font(.system(size: 80))
                    
                    Text("Ready to Make Money?")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        FeatureCheck(text: "90% revenue share")
                        FeatureCheck(text: "Real ads from Google & more")
                        FeatureCheck(text: "24-hour payouts")
                        FeatureCheck(text: "No minimum requirements")
                        FeatureCheck(text: "Real-time earnings tracking")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var buttonText: String {
        switch currentStep {
        case 0: return "Let's Go! 🚀"
        case 1: return "See How It Works"
        case 2: return "Enable Monetization"
        case 3: return isEnabled ? "Start Uploading!" : "Enable Monetization"
        default: return "Next"
        }
    }
    
    private func enableMonetization() {
        if isEnabled {
            onComplete()
            dismiss()
            return
        }
        
        isEnabling = true
        HapticManager.shared.impact(style: .heavy)
        
        // Simulate enable process
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                isEnabling = false
                isEnabled = true
                
                // Update user settings
                UserDefaults.standard.set(true, forKey: "monetization_enabled")
                
                // Track event
                if let userId = AuthenticationManager.shared.currentUser?.id {
                    RealTimeRevenueTracker.shared.startTracking(creatorId: userId)
                }
                
                HapticManager.shared.notification(type: .success)
            }
        }
    }
}

// MARK: - 🔥 SUPPORTING VIEWS

struct MonetizationComparisonRow: View {
    let feature: String
    let youtube: String
    let mychannel: String
    let isAnimated: Bool
    var myChannelHighlight: Bool = false
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 24) {
                // YouTube column
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.caption)
                    Text(youtube)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .frame(width: 60)
                
                // MyChannel column
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(mychannel)
                        .font(.caption)
                        .fontWeight(myChannelHighlight ? .bold : .regular)
                        .foregroundColor(.green)
                }
                .frame(width: 60)
            }
        }
        .padding(.vertical, 8)
    }
}

struct HowItWorksRow: View {
    let step: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text("\(step)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green.opacity(0.5))
        }
    }
}

struct FeatureCheck: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

struct MoneyParticlesView: View {
    @State private var particles: [MoneyParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text("💰")
                        .font(.system(size: particle.size))
                        .opacity(particle.opacity)
                        .position(particle.position)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        for _ in 0..<20 {
            let particle = MoneyParticle(
                id: UUID(),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 12...24),
                opacity: Double.random(in: 0.05...0.15)
            )
            particles.append(particle)
        }
    }
}

struct MoneyParticle: Identifiable {
    let id: UUID
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}

// MARK: - 🔥 QUICK MONETIZATION BANNER

struct QuickMonetizationBanner: View {
    @State private var showingOnboarding = false
    @AppStorage("monetization_enabled") private var isMonetizationEnabled = false
    @AppStorage("hide_monetization_banner") private var hideBanner = false
    
    var body: some View {
        if !isMonetizationEnabled && !hideBanner {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Earning from Day 1!")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("90% revenue share • No requirements")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button {
                        hideBanner = true
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Button {
                    showingOnboarding = true
                } label: {
                    Text("Enable Monetization")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
            )
            .sheet(isPresented: $showingOnboarding) {
                Day1MonetizationOnboarding {
                    isMonetizationEnabled = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Day 1 Monetization Onboarding") {
    Day1MonetizationOnboarding {
        print("Monetization enabled!")
    }
}

#Preview("Quick Monetization Banner") {
    VStack {
        QuickMonetizationBanner()
        Spacer()
    }
    .padding()
    .background(Color.black)
}






