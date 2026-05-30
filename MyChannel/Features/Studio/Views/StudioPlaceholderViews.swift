import SwiftUI
import AVKit
import Combine

// MARK: - Placeholder Views
struct MembershipMonetizationView: View {
    @Binding var settings: MembershipSettings
    @State var membershipEnabled = true
    @State var showingAddTier = false
    @State var tiers: [MonetizationMembershipTier] = [
        MonetizationMembershipTier(name: "Bronze", price: 4.99, perks: ["Early access to videos", "Custom badge"], color: .orange),
        MonetizationMembershipTier(name: "Silver", price: 9.99, perks: ["Everything in Bronze", "Members-only content", "Priority replies"], color: .gray),
        MonetizationMembershipTier(name: "Gold", price: 24.99, perks: ["Everything in Silver", "Monthly Q&A", "Exclusive merch discount"], color: .yellow)
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Channel Memberships")
                            .font(.system(size: 22, weight: .bold))
                        Text("Offer exclusive perks to your biggest supporters")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $membershipEnabled)
                        .labelsHidden()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(title: "Members", value: "1,234", icon: "person.3.fill", color: .blue)
                    StatBox(title: "Monthly", value: "$12.4K", icon: "dollarsign.circle.fill", color: .green)
                    StatBox(title: "Retention", value: "94%", icon: "chart.line.uptrend.xyaxis", color: .purple)
                }
                
                // Membership Tiers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Membership Tiers")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: { showingAddTier = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Tier")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    ForEach(tiers) { tier in
                        MembershipTierCard(tier: tier)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Revenue Share Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revenue Share")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You keep")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("90%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MyChannel takes")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("10%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Better revenue share than YouTube's 70/30 split")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Memberships")
    }
}

struct MonetizationMembershipTier: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var perks: [String]
    var color: Color
}

struct MembershipTierCard: View {
    let tier: MonetizationMembershipTier
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(tier.color.gradient)
                    .frame(width: 12, height: 12)
                
                Text(tier.name)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("$\(String(format: "%.2f", tier.price))/mo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(tier.color)
                            .font(.system(size: 14))
                        Text(perk)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MerchandiseMonetizationView: View {
    @Binding var settings: MerchandiseSettings
    @State var merchEnabled = true
    @State var showingAddProduct = false
    @State var products: [MerchProduct] = [
        MerchProduct(name: "Limited Edition Hoodie", price: 59.99, stock: 42, image: "tshirt", category: "Apparel"),
        MerchProduct(name: "Signature Hat", price: 29.99, stock: 128, image: "sun.haze", category: "Accessories"),
        MerchProduct(name: "Phone Case", price: 19.99, stock: 87, image: "iphone", category: "Tech")
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merchandise Store")
                            .font(.system(size: 22, weight: .bold))
                        Text("Sell your own branded products")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $merchEnabled)
                        .labelsHidden()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(title: "Products", value: "\(products.count)", icon: "bag.fill", color: .orange)
                    StatBox(title: "Orders", value: "342", icon: "shippingbox.fill", color: .blue)
                    StatBox(title: "Revenue", value: "$8.2K", icon: "dollarsign.circle.fill", color: .green)
                }
                
                // Products List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Products")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: { showingAddProduct = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Product")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    ForEach(products) { product in
                        MerchProductCard(product: product)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Integration Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Powered by MyChannel Merch")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("We handle everything:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "printer.fill", text: "Print on demand manufacturing")
                        FeatureRow(icon: "shippingbox.fill", text: "Worldwide shipping & fulfillment")
                        FeatureRow(icon: "creditcard.fill", text: "Secure payment processing")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Easy returns & exchanges")
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Merchandise")
    }
}

struct MerchProduct: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var stock: Int
    var image: String
    var category: String
}

struct MerchProductCard: View {
    let product: MerchProduct
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: product.image)
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 12) {
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(product.stock) in stock")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Text(product.category)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct DonationMonetizationView: View {
    @State var superChatEnabled = true
    @State var minDonation = 1.0
    @State var recentDonations: [Donation] = [
        Donation(username: "BigFan123", amount: 50.00, message: "Love your content! Keep it up! 🔥", timestamp: Date()),
        Donation(username: "CreatorSupport", amount: 100.00, message: "You're inspiring!", timestamp: Date().addingTimeInterval(-3600)),
        Donation(username: "TrueFan", amount: 25.00, message: "Been watching since day 1!", timestamp: Date().addingTimeInterval(-7200))
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Super Chat & Tips")
                            .font(.system(size: 22, weight: .bold))
                        Text("Let viewers support you during live streams")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $superChatEnabled)
                        .labelsHidden()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(title: "Today", value: "$425", icon: "heart.fill", color: .pink)
                    StatBox(title: "This Week", value: "$2.1K", icon: "calendar", color: .blue)
                    StatBox(title: "All Time", value: "$18.5K", icon: "chart.line.uptrend.xyaxis", color: .green)
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minimum Donation")
                                .font(.system(size: 14, weight: .medium))
                            Text("Set the minimum amount viewers can donate")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Amount", value: $minDonation, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Recent Donations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Super Chats")
                        .font(.system(size: 18, weight: .semibold))
                    
                    ForEach(recentDonations) { donation in
                        DonationCard(donation: donation)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Revenue Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("💵 Your Cut")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You keep")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("90%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.pink)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MyChannel + Processing")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("10%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Best revenue share in the industry")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Super Chat")
    }
}

struct Donation: Identifiable {
    let id = UUID()
    var username: String
    var amount: Double
    var message: String
    var timestamp: Date
}

struct DonationCard: View {
    let donation: Donation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(amountColor(for: donation.amount).gradient)
                    .frame(width: 8, height: 8)
                
                Text(donation.username)
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Text("$\(String(format: "%.2f", donation.amount))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(amountColor(for: donation.amount))
            }
            
            Text(donation.message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(timeAgo(from: donation.timestamp))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amountColor(for: donation.amount).opacity(0.1))
        )
    }
    
    func amountColor(for amount: Double) -> Color {
        if amount >= 100 { return AppTheme.Colors.primary }
        else if amount >= 50 { return AppTheme.Colors.accent }
        else if amount >= 10 { return AppTheme.Colors.warning }
        else { return AppTheme.Colors.textSecondary }
    }
    
    func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

struct RevenueAnalyticsView: View {
    @StateObject var analyticsService = AdvancedAnalyticsService.shared
    @State var selectedPeriod: RevenuePeriod = .month
    
    enum RevenuePeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case year = "12 Months"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(RevenuePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Total Revenue Card
                VStack(spacing: 12) {
                    Text("Total Revenue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("$\(String(format: "%.2f", analyticsService.estimatedRevenue))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("+\(String(format: "%.1f", analyticsService.revenueGrowth))% from last period")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Revenue Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Revenue by Source")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    let breakdown = getRevenueBreakdown()
                    
                    ForEach(breakdown, id: \.source) { item in
                        MonetizationRevenueSourceRow(
                            icon: item.icon,
                            source: item.source,
                            amount: item.amount,
                            percentage: item.percentage,
                            color: item.color
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Top Performing Videos
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Earning Videos")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    ForEach(0..<3, id: \.self) { index in
                        MonetizationTopEarningVideoRow(
                            rank: index + 1,
                            title: "Video Title \(index + 1)",
                            revenue: Double.random(in: 100...1000),
                            views: Int.random(in: 10000...100000)
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Payout Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Payout")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Balance")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("$2,847.50")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Payout Date")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("Dec 15")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {}) {
                        Text("Request Early Payout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.gradient)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Revenue Analytics")
    }
    
    func getRevenueBreakdown() -> [RevenueBreakdownItem] {
        return [
            RevenueBreakdownItem(source: "Ads", amount: 1234.56, percentage: 45, icon: "play.rectangle.fill", color: .red),
            RevenueBreakdownItem(source: "Memberships", amount: 987.50, percentage: 35, icon: "person.badge.plus.fill", color: .blue),
            RevenueBreakdownItem(source: "Super Chat", amount: 425.00, percentage: 15, icon: "heart.fill", color: .pink),
            RevenueBreakdownItem(source: "Merchandise", amount: 200.44, percentage: 5, icon: "bag.fill", color: .orange)
        ]
    }
}

struct RevenueBreakdownItem {
    let source: String
    let amount: Double
    let percentage: Int
    let icon: String
    let color: Color
}

struct MonetizationRevenueSourceRow: View {
    let icon: String
    let source: String
    let amount: Double
    let percentage: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source)
                    .font(.system(size: 16, weight: .semibold))
                
                ProgressView(value: Double(percentage), total: 100)
                    .tint(color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", amount))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                Text("\(percentage)%")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MonetizationTopEarningVideoRow: View {
    let rank: Int
    let title: String
    let revenue: Double
    let views: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                Text("\(views.formatted()) views")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", revenue))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700") ?? .yellow // Gold - acceptable for #1
        case 2: return AppTheme.Colors.textSecondary
        case 3: return AppTheme.Colors.textTertiary
        default: return AppTheme.Colors.textSecondary
        }
    }
}

struct AdPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ad Preview")
                    .font(.title)
                
                Text("This is how ads will appear in your videos")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ad Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// StudioSettingsView now in separate file: MyChannel/Features/Studio/Views/StudioSettingsView.swift


// ⚡ AIToolsStudioView + QuickTabs extracted to StudioAIViews.swift
