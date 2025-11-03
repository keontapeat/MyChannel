//
//  FanGiftingView.swift
//  MyChannel
//
//  FAN GIFTING SYSTEM - Send virtual gifts during live streams & videos
//  Real money for creators, fun animations for fans
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct FanGiftingView: View {
    @StateObject private var viewModel = FanGiftingViewModel()
    @State private var selectedGift: VirtualGift?
    @State private var showPurchaseSheet = false
    @State private var recipientCreator: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        giftingHero
                        
                        // Your Balance
                        balanceSection
                        
                        // Popular Gifts
                        popularGiftsSection
                        
                        // Gift Categories
                        categoriesSection
                        
                        // Recent Gifts Sent
                        recentGiftsSection
                        
                        // Gifts Received (Creator View)
                        if viewModel.isCreator {
                            giftsReceivedSection
                        }
                        
                        // Leaderboard
                        leaderboardSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Gifting")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showPurchaseSheet) {
            if let gift = selectedGift {
                GiftPurchaseSheet(gift: gift, recipient: recipientCreator, viewModel: viewModel)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadGiftingData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var giftingHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.35, blue: 0.65),
                            Color(red: 0.8, green: 0.2, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 30, weight: .bold))
                    Text("Gifting")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Show appreciation with virtual gifts")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "sparkles", text: "Animated")
                    featureBadge(icon: "dollarsign.circle.fill", text: "Real Money")
                    featureBadge(icon: "heart.fill", text: "Appreciation")
                }
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
    
    // MARK: - Balance Section
    private var balanceSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Gift Balance")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                    
                    Text("\(viewModel.giftBalance)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("coins")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            Button {
                // Buy more coins
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Buy Coins")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.primary)
                .clipShape(Capsule())
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Popular Gifts
    private var popularGiftsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Popular Gifts")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 14) {
                ForEach(viewModel.popularGifts) { gift in
                    GiftCard(gift: gift) {
                        selectedGift = gift
                        showPurchaseSheet = true
                    }
                }
            }
        }
    }
    
    // MARK: - Categories
    private var categoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Browse by Category")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GiftCategory.allCategories) { category in
                        CategoryChip(category: category) {
                            // Filter by category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Gifts
    private var recentGiftsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Gifts Sent")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: Text("All History")) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if viewModel.recentGiftsSent.isEmpty {
                EmptyGiftsView()
            } else {
                ForEach(viewModel.recentGiftsSent.prefix(5)) { transaction in
                    GiftTransactionRow(transaction: transaction)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Gifts Received (Creator)
    private var giftsReceivedSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Gifts Received")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", viewModel.totalEarningsFromGifts))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
            }
            
            ForEach(viewModel.giftsReceived.prefix(5)) { transaction in
                GiftTransactionRow(transaction: transaction, isReceived: true)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Leaderboard
    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Top Gifters This Week")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(Array(viewModel.topGifters.enumerated()), id: \.element.id) { index, gifter in
                TopGifterRow(rank: index + 1, gifter: gifter)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct GiftCard: View {
    let gift: VirtualGift
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(gift.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Text(gift.emoji)
                        .font(.system(size: 32))
                }
                
                Text(gift.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text("\(gift.price)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(gift.color.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

struct CategoryChip: View {
    let category: GiftCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(category.emoji)
                    .font(.system(size: 18))
                
                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(category.color.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

struct GiftTransactionRow: View {
    let transaction: GiftTransaction
    var isReceived: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Gift emoji
            ZStack {
                Circle()
                    .fill(transaction.gift.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Text(transaction.gift.emoji)
                    .font(.system(size: 24))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isReceived ? "From \(transaction.sender)" : "To \(transaction.recipient)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(transaction.gift.name)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(timeAgo(transaction.sentAt))
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("\(transaction.gift.price)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                if isReceived {
                    Text("$\(String(format: "%.2f", transaction.creatorEarnings))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TopGifterRow: View {
    let rank: Int
    let gifter: TopGifter
    
    var medalColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case 2: return Color(red: 0.7, green: 0.7, blue: 0.7)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.Colors.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Rank
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                if rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(medalColor)
                } else {
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            
            // Avatar
            AsyncImage(url: URL(string: gifter.avatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gifter.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(gifter.giftsGiven) gifts sent")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                Text("\(gifter.totalCoinsSpent)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(12)
        .background(rank <= 3 ? medalColor.opacity(0.05) : AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(rank <= 3 ? medalColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

struct EmptyGiftsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No gifts sent yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Send your first gift to support a creator!")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Gift Purchase Sheet
struct GiftPurchaseSheet: View {
    let gift: VirtualGift
    let recipient: String
    @ObservedObject var viewModel: FanGiftingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = 1
    @State private var message = ""
    
    var totalCost: Int {
        gift.price * quantity
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Gift Preview
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(gift.color.opacity(0.15))
                                .frame(width: 120, height: 120)
                            
                            Text(gift.emoji)
                                .font(.system(size: 80))
                        }
                        
                        Text(gift.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(gift.description)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Quantity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quantity")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 20) {
                            Button {
                                if quantity > 1 { quantity -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                            
                            Text("\(quantity)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .frame(width: 60)
                            
                            Button {
                                if quantity < 99 { quantity += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Optional Message
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add a message (optional)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TextField("Say something nice...", text: $message)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Total Cost
                    VStack(spacing: 12) {
                        HStack {
                            Text("Total Cost:")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.yellow)
                                Text("\(totalCost)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        Text("Your balance: \(viewModel.giftBalance) coins")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(16)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Send Button
                    Button {
                        // Send gift
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Send Gift")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [gift.color, gift.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: gift.color.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
                    .disabled(totalCost > viewModel.giftBalance)
                    .opacity(totalCost > viewModel.giftBalance ? 0.5 : 1.0)
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Send Gift")
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

#Preview {
    FanGiftingView()
}

