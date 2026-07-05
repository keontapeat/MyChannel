//
//  CreatorMonetizationView.swift
//  MyChannel
//
//  ONE-CLICK CREATOR MONETIZATION - 90% REVENUE SHARE! 🔥
//

import SwiftUI
import Charts
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CreatorMonetizationView: View {
    @StateObject private var viewModel = CreatorMonetizationViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showingPayoutSetup = false
    @State private var showingWithdraw = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if !viewModel.isMonetizationEnabled {
                    monetizationOnboarding
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Earnings Overview
                            earningsCard
                            
                            // Revenue Breakdown
                            revenueBreakdownCard
                            
                            // Earnings Chart
                            earningsChartCard
                            
                            // Top Earning Videos
                            topEarningVideosCard
                            
                            // Payment Info
                            paymentInfoCard
                            
                            // AI Optimization Tips
                            optimizationTipsCard
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Monetization")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingWithdraw = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Withdraw")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(16)
                    }
                    .disabled(viewModel.availableBalance < 0.01)
                }
            }
            .sheet(isPresented: $showingPayoutSetup) {
                PayoutSetupView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingWithdraw) {
                WithdrawFundsView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadMonetizationData()
            }
        }
    }
    
    // MARK: - Monetization Onboarding
    private var monetizationOnboarding: some View {
        VStack(spacing: 32) {
            // Hero Section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.2), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                
                Text("Start Earning from Your Videos")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Join thousands of creators making money on MyChannel")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 20) {
                BenefitRow(
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    title: "90% Revenue Share",
                    subtitle: "Best in the industry (vs YouTube's 55%)",
                    color: .green
                )
                
                BenefitRow(
                    icon: "bolt.circle.fill",
                    title: "Instant Approval",
                    subtitle: "Start earning immediately - no waiting!",
                    color: .orange
                )
                
                BenefitRow(
                    icon: "calendar.circle.fill",
                    title: "24-Hour Payouts",
                    subtitle: "Get paid daily (vs YouTube's 30+ days)",
                    color: .blue
                )
                
                BenefitRow(
                    icon: "shield.checkered.fill",
                    title: "No Minimum",
                    subtitle: "Withdraw anytime (vs YouTube's $100 minimum)",
                    color: .purple
                )
                
                BenefitRow(
                    icon: "eye.circle.fill",
                    title: "Full Transparency",
                    subtitle: "See every penny you earn in real-time",
                    color: .indigo
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            // CTA Button
            Button {
                viewModel.enableMonetization()
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Enable Monetization")
                        .fontWeight(.bold)
                    Image(systemName: "star.fill")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
            }
            
            // Fine Print
            Text("By enabling, you agree to MyChannel's Monetization Terms. No hidden fees or costs!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Earnings Card
    private var earningsCard: some View {
        VStack(spacing: 20) {
            // This Month's Earnings
            VStack(spacing: 8) {
                HStack {
                    Text("This Month's Earnings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.earningsChange >= 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                            Text("+\(viewModel.earningsChange, specifier: "%.0f")%")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    }
                }
                
                Text("$\(viewModel.monthlyEarnings, specifier: "%.2f")")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // Quick Stats
            HStack(spacing: 0) {
                QuickStat(
                    label: "Available",
                    value: String(format: "$%.2f", viewModel.availableBalance),
                    color: .green
                )
                
                Divider()
                
                QuickStat(
                    label: "Pending",
                    value: String(format: "$%.2f", viewModel.pendingBalance),
                    color: .orange
                )
                
                Divider()
                
                QuickStat(
                    label: "All Time",
                    value: String(format: "$%.2f", viewModel.totalEarnings),
                    color: .blue
                )
            }
            .frame(height: 60)
            
            // Quick Actions
            HStack(spacing: 12) {
                Button {
                    showingWithdraw = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Withdraw")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .disabled(viewModel.availableBalance < 0.01)
                
                Button {
                    showingPayoutSetup = true
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Payout Settings")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - Revenue Breakdown
    private var revenueBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revenue Breakdown")
                .font(.headline)
            
            VStack(spacing: 12) {
                CreatorRevenueSourceRow(
                    icon: "play.rectangle.fill",
                    title: "Video Ads",
                    amount: viewModel.videoAdsRevenue,
                    percentage: viewModel.videoAdsPercentage,
                    color: .blue
                )
                
                CreatorRevenueSourceRow(
                    icon: "person.2.fill",
                    title: "Memberships",
                    amount: viewModel.membershipsRevenue,
                    percentage: viewModel.membershipsPercentage,
                    color: .purple
                )
                
                CreatorRevenueSourceRow(
                    icon: "message.fill",
                    title: "Super Chat",
                    amount: viewModel.superChatRevenue,
                    percentage: viewModel.superChatPercentage,
                    color: .green
                )
                
                CreatorRevenueSourceRow(
                    icon: "bag.fill",
                    title: "Merchandise",
                    amount: viewModel.merchRevenue,
                    percentage: viewModel.merchPercentage,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Earnings Chart
    private var earningsChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Earnings Trend")
                    .font(.headline)
                Spacer()
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    Text("7D").tag(TimePeriod.week)
                    Text("30D").tag(TimePeriod.month)
                    Text("90D").tag(TimePeriod.quarter)
                    Text("1Y").tag(TimePeriod.year)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if #available(iOS 16.0, *) {
                Chart(viewModel.earningsData) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Earnings", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green.opacity(0.5), Color.green.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Earnings", item.amount)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Top Earning Videos
    private var topEarningVideosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Earning Videos")
                .font(.headline)
            
            ForEach(viewModel.topEarningVideos.prefix(5)) { video in
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        HStack {
                            Text("\(video.views) views")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                            Text("$\(video.earnings, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Payment Info
    private var paymentInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Information")
                .font(.headline)
            
            if viewModel.hasPaymentMethod {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.paymentMethodName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("••••\(viewModel.paymentMethodLast4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Change") {
                        showingPayoutSetup = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                // Next Payout
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Payout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("$\(viewModel.availableBalance, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Available to withdraw now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            showingWithdraw = true
                        } label: {
                            Text("Withdraw")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Payment Method Required")
                        .font(.headline)
                    Text("Add a payment method to receive earnings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showingPayoutSetup = true
                    } label: {
                        Text("Add Payment Method")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Optimization Tips
    private var optimizationTipsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Optimization Tips")
                    .font(.headline)
            }
            
            ForEach(viewModel.optimizationTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(tip)
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
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct QuickStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CreatorRevenueSourceRow: View {
    let icon: String
    let title: String
    let amount: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.tertiarySystemBackground))
                        Rectangle()
                            .fill(color)
                            .frame(width: geo.size.width * (percentage / 100))
                    }
                }
                .frame(height: 4)
                .cornerRadius(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(String(format: "%.0f%%", percentage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Payout Setup View

struct PayoutSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatorMonetizationViewModel
    @State private var selectedMethod: PayoutMethod = .bank
    @State private var accountNumber: String = ""
    @State private var routingNumber: String = ""
    @State private var accountHolderName: String = ""
    @State private var paypalEmail: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Method") {
                    Picker("Method", selection: $selectedMethod) {
                        Text("Bank Account").tag(PayoutMethod.bank)
                        Text("PayPal").tag(PayoutMethod.paypal)
                        Text("Stripe").tag(PayoutMethod.stripe)
                    }
                }
                
                if selectedMethod == .bank {
                    Section("Bank Details") {
                        TextField("Account Holder Name", text: $accountHolderName)
                        TextField("Account Number", text: $accountNumber)
                            .keyboardType(.numberPad)
                        TextField("Routing Number", text: $routingNumber)
                            .keyboardType(.numberPad)
                    }
                } else if selectedMethod == .paypal {
                    Section("PayPal") {
                        TextField("PayPal Email", text: $paypalEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }
                
                Section {
                    Button("Save Payment Method") {
                        viewModel.savePaymentMethod(
                            method: selectedMethod,
                            accountNumber: accountNumber,
                            routingNumber: routingNumber,
                            holderName: accountHolderName,
                            paypalEmail: paypalEmail
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Payout Setup")
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
    
    private var isValid: Bool {
        switch selectedMethod {
        case .bank:
            return !accountNumber.isEmpty && !routingNumber.isEmpty && !accountHolderName.isEmpty
        case .paypal:
            return !paypalEmail.isEmpty && paypalEmail.contains("@")
        case .stripe:
            return true
        }
    }
}

// MARK: - Withdraw Funds View

struct WithdrawFundsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatorMonetizationViewModel
    @State private var amount: Double = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Available Balance
                VStack(spacing: 8) {
                    Text("Available Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(viewModel.availableBalance, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding()
                
                // Withdraw Amount
                VStack(alignment: .leading, spacing: 12) {
                    Text("Withdraw Amount")
                        .font(.headline)
                    
                    HStack {
                        Text("$")
                            .font(.title)
                        TextField("0.00", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 36, weight: .bold))
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    HStack(spacing: 12) {
                        ForEach([25, 50, 100, 250], id: \.self) { quickAmount in
                            Button("$\(quickAmount)") {
                                amount = Double(quickAmount)
                            }
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    
                    Button("Withdraw All") {
                        amount = viewModel.availableBalance
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding()
                
                // Payment Method
                if viewModel.hasPaymentMethod {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("To: \(viewModel.paymentMethodName) ••••\(viewModel.paymentMethodLast4)")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Withdraw Button
                Button {
                    viewModel.withdrawFunds(amount: amount)
                    dismiss()
                } label: {
                    Text("Withdraw $\(amount, specifier: "%.2f")")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(amount > 0 && amount <= viewModel.availableBalance ? Color.green : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(amount <= 0 || amount > viewModel.availableBalance)
                
                Text("Funds typically arrive in 24 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Withdraw Funds")
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

// MARK: - View Model

@MainActor
class CreatorMonetizationViewModel: ObservableObject {
    @Published var isMonetizationEnabled: Bool = false
    @Published var monthlyEarnings: Double = 0
    @Published var availableBalance: Double = 0
    @Published var pendingBalance: Double = 0
    @Published var totalEarnings: Double = 0
    @Published var earningsChange: Double = 0
    
    @Published var videoAdsRevenue: Double = 0
    @Published var membershipsRevenue: Double = 0
    @Published var superChatRevenue: Double = 0
    @Published var merchRevenue: Double = 0
    
    @Published var videoAdsPercentage: Double = 0
    @Published var membershipsPercentage: Double = 0
    @Published var superChatPercentage: Double = 0
    @Published var merchPercentage: Double = 0
    
    @Published var selectedPeriod: TimePeriod = .month
    @Published var earningsData: [EarningsDataPoint] = []
    @Published var topEarningVideos: [VideoEarnings] = []
    @Published var optimizationTips: [String] = []
    
    @Published var hasPaymentMethod: Bool = false
    @Published var paymentMethodName: String = ""
    @Published var paymentMethodLast4: String = ""
    
    func loadMonetizationData() async {
        // Simulate data loading
        isMonetizationEnabled = true
        monthlyEarnings = Double.random(in: 1000...10000)
        availableBalance = Double.random(in: 500...5000)
        pendingBalance = Double.random(in: 100...1000)
        totalEarnings = Double.random(in: 10000...100000)
        earningsChange = Double.random(in: 10...100)
        
        videoAdsRevenue = monthlyEarnings * 0.75
        membershipsRevenue = monthlyEarnings * 0.15
        superChatRevenue = monthlyEarnings * 0.07
        merchRevenue = monthlyEarnings * 0.03
        
        videoAdsPercentage = 75
        membershipsPercentage = 15
        superChatPercentage = 7
        merchPercentage = 3
        
        loadEarningsData()
        loadTopEarningVideos()
        loadOptimizationTips()
        
        hasPaymentMethod = true
        paymentMethodName = "Bank Account"
        paymentMethodLast4 = "6789"
    }
    
    private func loadEarningsData() {
        let calendar = Calendar.current
        let today = Date()
        let days = selectedPeriod == .week ? 7 : (selectedPeriod == .month ? 30 : (selectedPeriod == .quarter ? 90 : 365))
        
        earningsData = (0..<days).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            return EarningsDataPoint(
                date: date,
                amount: Double.random(in: 50...500),
                source: nil
            )
        }.reversed()
    }
    
    private func loadTopEarningVideos() {
        topEarningVideos = [
            VideoEarnings(
                id: "1",
                title: "My Viral Video - How to Get 1 Million Views",
                thumbnailUrl: "https://picsum.photos/300/200?random=1",
                views: 1234567,
                earnings: 3456.78
            ),
            VideoEarnings(
                id: "2",
                title: "Tutorial: Complete Beginner's Guide",
                thumbnailUrl: "https://picsum.photos/300/200?random=2",
                views: 890123,
                earnings: 2234.56
            ),
            VideoEarnings(
                id: "3",
                title: "Behind the Scenes Vlog",
                thumbnailUrl: "https://picsum.photos/300/200?random=3",
                views: 567890,
                earnings: 1123.45
            )
        ]
    }
    
    private func loadOptimizationTips() {
        optimizationTips = [
            "💡 Upload at 6pm EST for 30% more views (prime time!)",
            "💡 Videos 10-15 minutes long earn 2x more from ads",
            "💡 Enable mid-roll ads on videos over 8 minutes",
            "💡 Gaming content has your highest CPM ($" + String(format: "%.2f", Double.random(in: 20...30)) + ")",
            "💡 Add end screens to increase watch time by 25%"
        ]
    }
    
    func enableMonetization() {
        isMonetizationEnabled = true
        HapticManager.shared.impact(style: .medium)
        Task {
            await loadMonetizationData()
        }
    }
    
    func savePaymentMethod(
        method: PayoutMethod,
        accountNumber: String,
        routingNumber: String,
        holderName: String,
        paypalEmail: String
    ) {
        // Save payment method pref to Firestore (no raw account numbers — just the type and masked last4)
        guard let uid = AuthenticationManager.shared.currentUser?.id else { return }
        let methodName: String
        let last4: String
        switch method {
        case .bank:
            methodName = "Bank Account"
            last4 = String(accountNumber.suffix(4))
        case .paypal:
            methodName = "PayPal"
            last4 = String(paypalEmail.prefix(4))
        case .stripe:
            methodName = "Stripe"
            last4 = "****"
        }
        Task {
            #if canImport(FirebaseFirestore)
            try? await Firestore.firestore().collection("payout_settings").document(uid).setData([
                "methodType": methodName,
                "maskedLast4": last4,
                "holderName": holderName,
                "updatedAt": Timestamp(date: Date()),
            ], merge: true)
            #endif
        }
        hasPaymentMethod = true
        paymentMethodName = methodName
        paymentMethodLast4 = last4
        HapticManager.shared.impact(style: .medium)
    }
    
    func withdrawFunds(amount: Double) {
        // File a payout request — the server-side Cloud Function processes it.
        // MONEY NOTE: we never move money client-side; we just write a request record.
        guard let uid = AuthenticationManager.shared.currentUser?.id else { return }
        let amountCents = Int(amount * 100)
        Task {
            #if canImport(FirebaseFirestore)
            try? await Firestore.firestore().collection("payout_requests").addDocument(data: [
                "creatorId": uid,
                "amountCents": amountCents,
                "currency": "USD",
                "status": "pending",
                "createdAt": Timestamp(date: Date()),
            ])
            #endif
        }
        availableBalance -= amount
        HapticManager.shared.impact(style: .heavy)
        print("💰 Withdrawal request for $\(amount) filed")
    }
}

enum PayoutMethod {
    case bank, paypal, stripe
}

struct VideoEarnings: Identifiable {
    let id: String
    let title: String
    let thumbnailUrl: String
    let views: Int
    let earnings: Double
}

