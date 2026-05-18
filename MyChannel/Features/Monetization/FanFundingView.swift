//
//  FanFundingView.swift
//  MyChannel
//
//  FAN FUNDING TIERS - Built-in Patreon Killer
//  Monthly subscriptions, perks, exclusive content
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct FanFundingView: View {
    @StateObject private var viewModel = FanFundingViewModel()
    @State private var showCreateTier = false
    @State private var showManagePerks = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        fundingHero
                        
                        // Stats Overview
                        statsSection
                        
                        // Active Tiers
                        tiersSection
                        
                        // Top Supporters
                        topSupportersSection
                        
                        // Exclusive Content
                        exclusiveContentSection
                        
                        // Revenue Analytics
                        revenueAnalyticsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Fan Funding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateTier = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateTier) {
            CreateTierSheet(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadFundingData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var fundingHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.6, blue: 0.9),
                            Color(red: 0.1, green: 0.4, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text("Fan Funding")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Build a sustainable income with your fans")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "dollarsign.circle.fill", text: "Monthly Income")
                    featureBadge(icon: "star.fill", text: "Exclusive Perks")
                    featureBadge(icon: "crown.fill", text: "VIP Access")
                }
                
                Text("🔥 Keep 95% of all fan contributions!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                FundingStatCard(
                    icon: "person.3.fill",
                    value: "\(viewModel.totalSupporters)",
                    label: "Supporters",
                    color: .blue
                )
                
                FundingStatCard(
                    icon: "dollarsign.circle.fill",
                    value: "$\(viewModel.monthlyRecurring)",
                    label: "Monthly",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                FundingStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "+\(viewModel.growthRate)%",
                    label: "Growth",
                    color: .purple
                )
                
                FundingStatCard(
                    icon: "banknote.fill",
                    value: "$\(viewModel.lifetimeEarnings)",
                    label: "Lifetime",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Tiers Section
    private var tiersSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Membership Tiers")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showCreateTier = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Tier")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if viewModel.tiers.isEmpty {
                EmptyTiersView()
            } else {
                ForEach(viewModel.tiers) { tier in
                    FundingTierCard(tier: tier, viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: - Top Supporters
    private var topSupportersSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Top Supporters")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                NavigationLink(destination: Text("All Supporters")) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ForEach(viewModel.topSupporters.prefix(5)) { supporter in
                SupporterRow(supporter: supporter)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Exclusive Content
    private var exclusiveContentSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Exclusive Content")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: Text("Manage Content")) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text("Manage")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.exclusiveContent) { content in
                        ExclusiveContentCard(content: content)
                    }
                }
            }
        }
    }
    
    // MARK: - Revenue Analytics
    private var revenueAnalyticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Revenue Analytics")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 14) {
                RevenueBreakdownRow(
                    label: "Monthly Subscriptions",
                    amount: viewModel.subscriptionRevenue,
                    percentage: 75,
                    color: .blue
                )
                
                RevenueBreakdownRow(
                    label: "One-Time Tips",
                    amount: viewModel.tipRevenue,
                    percentage: 15,
                    color: .green
                )
                
                RevenueBreakdownRow(
                    label: "Exclusive Content",
                    amount: viewModel.contentRevenue,
                    percentage: 10,
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct FundingStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FundingTierCard: View {
    let tier: FundingTier
    let viewModel: FanFundingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: tier.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(tier.color)
                        
                        Text(tier.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Text("$\(String(format: "%.2f", tier.price))/month")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(tier.subscriberCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("members")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Text(tier.description)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Perks:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                ForEach(tier.perks.prefix(4), id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        
                        Text(perk)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                if tier.perks.count > 4 {
                    Text("+\(tier.perks.count - 4) more perks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    // Edit tier
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button {
                    // View analytics
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                        Text("Analytics")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(18)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(tier.color.opacity(0.3), lineWidth: 2)
        )
    }
}

struct EmptyTiersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No membership tiers yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Create tiers to let fans support you monthly")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct SupporterRow: View {
    let supporter: FanSupporter
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: supporter.avatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(supporter.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if supporter.isTopSupporter {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(supporter.tierName)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", supporter.monthlyAmount))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("/ month")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExclusiveContentCard: View {
    let content: ExclusiveContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: content.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text(content.requiredTier)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
                .padding(8)
                , alignment: .topLeading
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(content.views) views")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(width: 200)
    }
}

struct RevenueBreakdownRow: View {
    let label: String
    let amount: Int
    let percentage: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("$\(amount)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("(\(percentage)%)")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.cardBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage) / 100.0, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Create Tier Sheet
struct CreateTierSheet: View {
    @ObservedObject var viewModel: FanFundingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var tierName = ""
    @State private var tierPrice = ""
    @State private var tierDescription = ""
    @State private var selectedIcon = "star.fill"
    @State private var perks: [String] = [""]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Create a new membership tier for your fans")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Tier details form
                    VStack(alignment: .leading, spacing: 18) {
                        FormField(label: "Tier Name", placeholder: "e.g., Gold Member", text: $tierName)
                        FormField(label: "Monthly Price", placeholder: "9.99", text: $tierPrice)
                        FormField(label: "Description", placeholder: "Describe what members get", text: $tierDescription, isMultiline: true)
                    }
                    
                    Button("Create Tier") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("New Membership Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if isMultiline {
                UIKitMultilineTextView(
                    text: $text,
                    placeholder: placeholder
                )
                    .padding(12)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    FanFundingView()
}

