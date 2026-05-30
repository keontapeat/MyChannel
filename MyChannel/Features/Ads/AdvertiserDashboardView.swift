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
            AdvertiserStatCard(
                title: "Impressions",
                value: viewModel.formatNumber(viewModel.totalImpressions),
                change: viewModel.impressionsChange,
                icon: "eye.fill",
                color: .blue
            )
            
            AdvertiserStatCard(
                title: "Clicks",
                value: viewModel.formatNumber(viewModel.totalClicks),
                change: viewModel.clicksChange,
                icon: "hand.tap.fill",
                color: .green
            )
            
            AdvertiserStatCard(
                title: "CTR",
                value: String(format: "%.1f%%", viewModel.ctr),
                change: viewModel.ctrChange,
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            
            AdvertiserStatCard(
                title: "ROI",
                value: String(format: "%.0f%%", viewModel.roi),
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
                AdvertiserQuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Create Campaign",
                    color: .blue
                ) {
                    showingCreateCampaign = true
                }
                
                AdvertiserQuickActionButton(
                    icon: "photo.on.rectangle.angled",
                    title: "Upload Creative",
                    color: .green
                ) {
                    // TODO
                }
                
                AdvertiserQuickActionButton(
                    icon: "person.3.fill",
                    title: "Build Audience",
                    color: .orange
                ) {
                    selectedTab = .audiences
                }
                
                AdvertiserQuickActionButton(
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
                AdvertiserEmptyStateView(
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
            AdvertiserMetricCard(title: "Conversions", value: "\(viewModel.totalConversions)", icon: "checkmark.circle.fill", color: .green)
            AdvertiserMetricCard(title: "Conversion Rate", value: String(format: "%.1f%%", viewModel.conversionRate), icon: "percent", color: .blue)
            AdvertiserMetricCard(title: "Avg CPC", value: String(format: "$%.2f", viewModel.avgCPC), icon: "dollarsign.circle", color: .orange)
            AdvertiserMetricCard(title: "Total Spend", value: String(format: "$%.2f", viewModel.totalSpend), icon: "creditcard.fill", color: .purple)
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
                AdvertiserPaymentMethodRow(method: method)
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


// ⚡ Supporting views extracted to AdvertiserComponents.swift
