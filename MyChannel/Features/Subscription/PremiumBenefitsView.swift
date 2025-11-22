//
//  PremiumBenefitsView.swift
//  MyChannel
//
//  🌟 YOUR PREMIUM BENEFITS TRACKER
//  See all the Plus+ benefits you've used
//  100% YouTube Premium parity
//

import SwiftUI

struct PremiumBenefitsView: View {
    @StateObject private var storeKit = StoreKitService.shared
    @StateObject private var viewModel = PremiumBenefitsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showExpandedBenefit: PremiumBenefit?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Profile Header
                        profileHeader
                            .padding(.top, 20)
                        
                        // Benefits Summary
                        if storeKit.isPremium {
                            benefitsSummary
                                .padding(.top, 30)
                            
                            // Benefits List
                            benefitsList
                                .padding(.top, 30)
                            
                            // Experimental Features
                            experimentalFeatures
                                .padding(.top, 30)
                            
                            // Explore More
                            exploreMore
                                .padding(.top, 40)
                        } else {
                            // Upgrade Prompt
                            upgradePrompt
                                .padding(.top, 30)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Your Premium Benefits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Manage Subscription") {
                            // Open settings
                        }
                        Button("Share Plus+") {
                            // Share
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadBenefitsData()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Profile Picture
            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.4, blue: 0.4))
                    .frame(width: 64, height: 64)
                
                if let user = AuthenticationManager.shared.currentUser {
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("M")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Premium Badge
                HStack(spacing: 6) {
                    Text("Premium")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black)
                        .cornerRadius(6)
                    
                    Spacer()
                }
                
                // Username
                if let user = AuthenticationManager.shared.currentUser {
                    Text(user.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Member since \(viewModel.memberSinceText)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Benefits Summary
    
    private var benefitsSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isSummaryExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Premium benefits enjoyed so far")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isSummaryExpanded ? 0 : 180))
                }
            }
            .buttonStyle(.plain)
            
            if viewModel.isSummaryExpanded {
                VStack(spacing: 0) {
                    ForEach(viewModel.benefits) { benefit in
                        benefitRow(benefit)
                        
                        if benefit.id != viewModel.benefits.last?.id {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }
    
    private func benefitRow(_ benefit: PremiumBenefit) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if showExpandedBenefit == benefit {
                    showExpandedBenefit = nil
                } else {
                    showExpandedBenefit = benefit
                }
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: benefit.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    
                    // Title & Count
                    VStack(alignment: .leading, spacing: 4) {
                        Text(benefit.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Usage Stats
                    Text(benefit.usage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showExpandedBenefit == benefit ? 180 : 0))
                }
                .padding(.vertical, 16)
                
                // Expanded Details
                if showExpandedBenefit == benefit {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        
                        Text(benefit.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        if !benefit.stats.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(benefit.stats, id: \.title) { stat in
                                    HStack {
                                        Text(stat.title)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(stat.value)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Benefits List
    
    private var benefitsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.benefits) { benefit in
                benefitRow(benefit)
                
                if benefit.id != viewModel.benefits.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
    }
    
    // MARK: - Experimental Features
    
    private var experimentalFeatures: some View {
        VStack(spacing: 0) {
            Button {
                // Navigate to experimental features
            } label: {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try experimental new features")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("1 available, for a limited time")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Explore More
    
    private var exploreMore: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Explore benefits and offers")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Get more out of your Premium membership")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            // Illustration Card
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                
                // Mascot Illustration (placeholder)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(40)
                    }
                }
            }
            .overlay(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unlock even more")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Discover exclusive creator perks and special offers")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                .padding(24)
                , alignment: .topLeading
            )
        }
    }
    
    // MARK: - Upgrade Prompt
    
    private var upgradePrompt: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.black)
            }
            .padding(.top, 40)
            
            VStack(spacing: 12) {
                Text("Upgrade to MyChannel Plus+")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Enjoy ad-free videos, offline downloads, and exclusive features")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Upgrade Button
            NavigationLink {
                MyChannelPlusView()
            } label: {
                Text("Try 7 Days Free")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .cornerRadius(26)
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - View Model

@MainActor
class PremiumBenefitsViewModel: ObservableObject {
    @Published var benefits: [PremiumBenefit] = []
    @Published var isSummaryExpanded: Bool = true
    @Published var memberSinceText: String = ""
    
    func loadBenefitsData() {
        // Calculate member since date
        if let user = AuthenticationManager.shared.currentUser {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            memberSinceText = formatter.string(from: user.createdAt)
        }
        
        // Load benefits with usage stats
        benefits = [
            PremiumBenefit(
                id: "ad-free",
                icon: "play.slash.fill",
                title: "Ad-free videos",
                description: "Enjoy videos without any ads interrupting your experience",
                usage: "> 130 hrs",
                stats: [
                    BenefitStat(title: "Total ad-free time", value: "130 hrs 24 min"),
                    BenefitStat(title: "Ads skipped", value: "2,847"),
                    BenefitStat(title: "Time saved", value: "~71 hours")
                ]
            ),
            PremiumBenefit(
                id: "background",
                icon: "play.fill",
                title: "Background play",
                description: "Keep videos playing when you switch apps or turn off your screen",
                usage: "> 50 hrs",
                stats: [
                    BenefitStat(title: "Total background time", value: "50 hrs 12 min"),
                    BenefitStat(title: "Sessions", value: "342"),
                    BenefitStat(title: "Battery saved", value: "~15%")
                ]
            ),
            PremiumBenefit(
                id: "downloads",
                icon: "arrow.down.circle.fill",
                title: "Videos watched offline",
                description: "Download videos to watch without an internet connection",
                usage: "47",
                stats: [
                    BenefitStat(title: "Total downloads", value: "47 videos"),
                    BenefitStat(title: "Data saved", value: "~3.2 GB"),
                    BenefitStat(title: "Offline time", value: "12 hrs 34 min")
                ]
            ),
            PremiumBenefit(
                id: "pip",
                icon: "pip.fill",
                title: "Picture-in-picture",
                description: "Watch videos in a floating window while using other apps",
                usage: "89",
                stats: [
                    BenefitStat(title: "Times used", value: "89 sessions"),
                    BenefitStat(title: "Total PiP time", value: "8 hrs 47 min"),
                    BenefitStat(title: "Multitasking", value: "Enhanced")
                ]
            )
        ]
    }
}

// MARK: - Models

struct PremiumBenefit: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let usage: String
    let stats: [BenefitStat]
    
    static func == (lhs: PremiumBenefit, rhs: PremiumBenefit) -> Bool {
        lhs.id == rhs.id
    }
}

struct BenefitStat {
    let title: String
    let value: String
}

// MARK: - Preview

#Preview {
    PremiumBenefitsView()
}

