//
//  AdvertiserDashboardView.swift
//  MyChannel
//
//  THE WORLD'S BEST ADVERTISER PLATFORM
//  Self-serve, AI-powered, 3x better ROI than competitors
//

import SwiftUI
import Charts

struct AdvertiserDashboardView: View {
    @StateObject private var viewModel = AdvertiserViewModel()
    @State private var selectedTab: Tab = .overview
    @State private var showingCreateCampaign = false
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case campaigns = "Campaigns"
        case analytics = "Analytics"
        case billing = "Billing"
        case audiences = "Audiences"
        case creatives = "Creatives"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Stats Bar
                    topStatsBar
                    
                    // Tab Picker
                    Picker("Section", selection: $selectedTab) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            switch selectedTab {
                            case .overview:
                                overviewContent
                            case .campaigns:
                                campaignsContent
                            case .analytics:
                                analyticsContent
                            case .billing:
                                billingContent
                            case .audiences:
                                audiencesContent
                            case .creatives:
                                creativesContent
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("MyChannel Ads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateCampaign = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("New Campaign")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                }
            }
            .sheet(isPresented: $showingCreateCampaign) {
                CreateCampaignView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Top Stats Bar
    private var topStatsBar: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Impressions",
                value: viewModel.formatNumber(viewModel.totalImpressions),
                change: viewModel.impressionsChange,
                icon: "eye.fill",
                color: .blue
            )
            
            StatCard(
                title: "Clicks",
                value: viewModel.formatNumber(viewModel.totalClicks),
                change: viewModel.clicksChange,
                icon: "hand.tap.fill",
                color: .green
            )
            
            StatCard(
                title: "CTR",
                value: "\(viewModel.ctr, specifier: "%.1f")%",
                change: viewModel.ctrChange,
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            
            StatCard(
                title: "ROI",
                value: "\(viewModel.roi, specifier: "%.0f")%",
                change: viewModel.roiChange,
                icon: "dollarsign.circle.fill",
                color: .purple
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Overview Content
    private var overviewContent: some View {
        VStack(spacing: 24) {
            // Campaign Performance Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Campaign Performance (Last 30 Days)")
                    .font(.headline)
                
                if #available(iOS 16.0, *) {
                    Chart(viewModel.performanceData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Impressions", item.impressions)
                        )
                        .foregroundStyle(.blue)
                        
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Clicks", item.clicks * 100)
                        )
                        .foregroundStyle(.green)
                    }
                    .frame(height: 200)
                    .chartLegend(position: .bottom)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // AI Insights
            aiInsightsSection
            
            // Active Campaigns
            activeCampaignsSection
            
            // Quick Actions
            quickActionsSection
        }
    }
    
    // MARK: - AI Insights
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Insights & Recommendations")
                    .font(.headline)
            }
            
            ForEach(viewModel.aiInsights, id: \.self) { insight in
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(insight)
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Active Campaigns
    private var activeCampaignsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Campaigns")
                .font(.headline)
            
            ForEach(viewModel.campaigns.prefix(5)) { campaign in
                CampaignRow(campaign: campaign)
            }
            
            if viewModel.campaigns.count > 5 {
                Button("View All Campaigns") {
                    selectedTab = .campaigns
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Create Campaign",
                    color: .blue
                ) {
                    showingCreateCampaign = true
                }
                
                QuickActionButton(
                    icon: "photo.on.rectangle.angled",
                    title: "Upload Creative",
                    color: .green
                ) {
                    // TODO
                }
                
                QuickActionButton(
                    icon: "person.3.fill",
                    title: "Build Audience",
                    color: .orange
                ) {
                    selectedTab = .audiences
                }
                
                QuickActionButton(
                    icon: "creditcard.fill",
                    title: "Add Funds",
                    color: .purple
                ) {
                    selectedTab = .billing
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Campaigns Content
    private var campaignsContent: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.campaigns) { campaign in
                CampaignDetailCard(campaign: campaign, viewModel: viewModel)
            }
            
            if viewModel.campaigns.isEmpty {
                EmptyStateView(
                    icon: "megaphone.fill",
                    title: "No Campaigns Yet",
                    message: "Create your first campaign and start reaching millions of viewers!",
                    actionTitle: "Create Campaign"
                ) {
                    showingCreateCampaign = true
                }
            }
        }
    }
    
    // MARK: - Analytics Content
    private var analyticsContent: some View {
        VStack(spacing: 24) {
            // Performance Metrics
            metricsGrid
            
            // Conversion Funnel
            conversionFunnel
            
            // Top Performing Creatives
            topCreativesSection
            
            // Audience Demographics
            demographicsSection
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(title: "Conversions", value: "\(viewModel.totalConversions)", icon: "checkmark.circle.fill", color: .green)
            MetricCard(title: "Conversion Rate", value: "\(viewModel.conversionRate, specifier: "%.1f")%", icon: "percent", color: .blue)
            MetricCard(title: "Avg CPC", value: "$\(viewModel.avgCPC, specifier: "%.2f")", icon: "dollarsign.circle", color: .orange)
            MetricCard(title: "Total Spend", value: "$\(viewModel.totalSpend, specifier: "%.2f")", icon: "creditcard.fill", color: .purple)
        }
    }
    
    private var conversionFunnel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion Funnel")
                .font(.headline)
            
            FunnelStage(label: "Impressions", value: viewModel.totalImpressions, percentage: 100, color: .blue)
            FunnelStage(label: "Clicks", value: viewModel.totalClicks, percentage: viewModel.clickPercentage, color: .green)
            FunnelStage(label: "Conversions", value: viewModel.totalConversions, percentage: viewModel.conversionPercentage, color: .purple)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var topCreativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performing Creatives")
                .font(.headline)
            
            ForEach(viewModel.topCreatives.prefix(3)) { creative in
                HStack {
                    AsyncImage(url: URL(string: creative.thumbnailUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(creative.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack {
                            Text("\(creative.ctr, specifier: "%.1f")% CTR")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("•")
                            Text("\(creative.conversions) conversions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("⭐⭐⭐⭐⭐")
                            .font(.caption2)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var demographicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audience Demographics")
                .font(.headline)
            
            VStack(spacing: 8) {
                DemographicBar(label: "18-24", percentage: 35, color: .blue)
                DemographicBar(label: "25-34", percentage: 40, color: .green)
                DemographicBar(label: "35-44", percentage: 20, color: .orange)
                DemographicBar(label: "45+", percentage: 5, color: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Billing Content
    private var billingContent: some View {
        VStack(spacing: 24) {
            // Account Balance
            accountBalanceCard
            
            // Payment Methods
            paymentMethodsSection
            
            // Transaction History
            transactionHistorySection
        }
    }
    
    private var accountBalanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Account Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(viewModel.accountBalance, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold))
                }
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button {
                    viewModel.showingAddFunds = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Funds")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button {
                    // Auto-reload settings
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Auto-Reload")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Payment Methods")
                    .font(.headline)
                Spacer()
                Button("Add New") {
                    viewModel.showingAddPaymentMethod = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ForEach(viewModel.paymentMethods) { method in
                PaymentMethodRow(method: method)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction History")
                .font(.headline)
            
            ForEach(viewModel.transactions.prefix(10)) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Audiences Content
    private var audiencesContent: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.showingCreateAudience = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Custom Audience")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            ForEach(viewModel.audiences) { audience in
                AudienceCard(audience: audience)
            }
        }
    }
    
    // MARK: - Creatives Content
    private var creativesContent: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.showingUploadCreative = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Upload New Creative")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.creatives) { creative in
                    CreativeCard(creative: creative)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let change: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text("\(abs(change), specifier: "%.1f")%")
                    .font(.caption2)
            }
            .foregroundColor(change >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct CampaignRow: View {
    let campaign: AdCampaign
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(campaign.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(campaign.status.rawValue)
                    .font(.caption)
                    .foregroundColor(campaign.status == .active ? .green : .orange)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(campaign.spent, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("of $\(campaign.budget, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct CampaignDetailCard: View {
    let campaign: AdCampaign
    let viewModel: AdvertiserViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(campaign.name)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Edit") { }
                    Button("Pause") { }
                    Button("Duplicate") { }
                    Button("Delete", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            HStack(spacing: 16) {
                MetricPill(label: "Impressions", value: "\(campaign.impressions)")
                MetricPill(label: "Clicks", value: "\(campaign.clicks)")
                MetricPill(label: "CTR", value: "\(campaign.ctr, specifier: "%.1f")%")
            }
            
            ProgressView(value: campaign.spent / campaign.budget)
                .tint(.blue)
            
            HStack {
                Text("Spent: $\(campaign.spent, specifier: "%.2f")")
                    .font(.caption)
                Spacer()
                Text("Budget: $\(campaign.budget, specifier: "%.2f")")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct FunnelStage: View {
    let label: String
    let value: Int
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("(\(percentage, specifier: "%.1f")%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.tertiarySystemBackground))
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * (percentage / 100))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

struct DemographicBar: View {
    let label: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.tertiarySystemBackground))
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * (percentage / 100))
                }
            }
            .frame(height: 20)
            .cornerRadius(4)
            Text("\(percentage, specifier: "%.0f")%")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct PaymentMethodRow: View {
    let method: PaymentMethod
    
    var body: some View {
        HStack {
            Image(systemName: method.type == .card ? "creditcard.fill" : "building.columns.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(method.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("••••" + method.last4)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if method.isDefault {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(transaction.type == .credit ? "+$\(transaction.amount, specifier: "%.2f")" : "-$\(transaction.amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.type == .credit ? .green : .primary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct AudienceCard: View {
    let audience: Audience
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(audience.name)
                    .font(.headline)
                Spacer()
                Text("\(audience.size) users")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(audience.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                ForEach(audience.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct CreativeCard: View {
    let creative: Creative
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: creative.thumbnailUrl)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .aspectRatio(16/9, contentMode: .fill)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(creative.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack {
                    Text("\(creative.ctr, specifier: "%.1f")% CTR")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Spacer()
                    Image(systemName: creative.status == .approved ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                        .foregroundColor(creative.status == .approved ? .green : .orange)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: action) {
                Text(actionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

