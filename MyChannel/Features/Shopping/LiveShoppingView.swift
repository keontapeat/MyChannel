//
//  LiveShoppingView.swift
//  MyChannel
//
//  LIVE SHOPPING NETWORK - Shop during live streams
//  AR try-on, instant checkout, creator commissions
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import ARKit

struct LiveShoppingView: View {
    @StateObject private var viewModel = LiveShoppingViewModel()
    @State private var selectedProduct: ShoppingProduct?
    @State private var showARTryOn = false
    @State private var showCheckout = false
    @State private var selectedFilter: LiveShoppingFilter = .live
    
    private let metrics = ShoppingMetric.defaultMetrics
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 28) {
                    heroSection
                    metricsSection
                    filtersSection
                    trendingProductsSection
                    categoriesSection
                    creatorSpotlightSection
                    flashDealsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Live Shopping")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailSheet(product: product, showARTryOn: $showARTryOn, showCheckout: $showCheckout)
        }
        .fullScreenCover(isPresented: $showARTryOn) {
            if let product = selectedProduct {
                ARTryOnView(product: product)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadLiveShops()
            }
        }
    }
    
    // MARK: - Sections
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("Live now")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(viewModel.liveShows.count) shows")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.liveShows) { show in
                        LiveShowHeroCard(show: show)
                    }
                }
            }
        }
    }
    
    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(metrics) { metric in
                ShoppingMetricCard(metric: metric)
            }
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discover")
                .font(AppTheme.Typography.title3)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LiveShoppingFilter.allCases) { filter in
                        QuickFilterPill(
                            filter: filter,
                            isSelected: filter == selectedFilter
                        ) {
                            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var trendingProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trending right now")
                        .font(AppTheme.Typography.title3)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Curated drops updated hourly")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button {
                    // TODO: navigate to full catalog
                } label: {
                    Text("View all")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredProducts) { product in
                        ProductHighlightCard(product: product) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shop by category")
                .font(AppTheme.Typography.title3)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(ShoppingCategory.allCases) { category in
                    CategoryButton(category: category) {
                        // TODO: route to category storefront
                    }
                }
            }
        }
    }
    
    private var creatorSpotlightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Creator spotlight")
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button {
                    // TODO: navigate
                } label: {
                    Text("Browse all")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.creatorShops) { shop in
                        CreatorSpotlightCard(shop: shop)
                    }
                }
            }
        }
    }
    
    private var flashDealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Flash deals")
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Label(viewModel.flashSaleTimeRemaining, systemImage: "clock.badge.exclamationmark")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.flashSaleProducts) { product in
                    FlashDealCard(product: product) {
                        selectedProduct = product
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct LiveShowHeroCard: View {
    let show: LiveShoppingShow
    
    var body: some View {
        NavigationLink(destination: LiveShoppingStreamView(show: show)) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: show.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.Colors.error, in: Capsule())
                            
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                Text("\(show.viewerCount.abbreviated)")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.4), in: Capsule())
                        }
                        
                        Text(show.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .padding(16)
                }
                
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: show.creator.avatarURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.backgroundSecondary)
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(show.creator.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Streaming now")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Watch")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary.opacity(0.12), in: Capsule())
                }
            }
            .frame(width: 300)
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct ProductHighlightCard: View {
    let product: ShoppingProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: product.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    if product.hasARTryOn {
                        Image(systemName: "arkit")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(AppTheme.Colors.primary, in: Circle())
                            .padding(10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.brand.uppercased())
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(product.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        if product.discount > 0 {
                            Text("$\(product.originalPrice)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .strikethrough()
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 11))
                        Text(String(format: "%.1f", product.rating))
                            .font(AppTheme.Typography.caption)
                        Text("(\(product.reviews))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(width: 220)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CategoryButton: View {
    let category: ShoppingCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(category.color, in: RoundedRectangle(cornerRadius: 14))
                
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct CreatorSpotlightCard: View {
    let shop: CreatorShop
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: shop.creator.avatarURL)) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(AppTheme.Colors.backgroundSecondary)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(shop.creator.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("\(shop.productCount) products • \(shop.rating, specifier: "%.1f") ★")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total sales")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("$\(shop.totalSales.formatted(.number.notation(.compactName)))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Label("Follow", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary.opacity(0.12), in: Capsule())
            }
        }
        .frame(width: 260)
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 0.8)
        )
    }
}

struct FlashDealCard: View {
    let product: ShoppingProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: product.imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(product.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("$\(product.originalPrice)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .strikethrough()
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(product.discount)% off")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.error, in: Capsule())
                        
                        Text("\(product.stockRemaining) left")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer(minLength: 12)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShoppingMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let trend: String
    let icon: String
    let iconColor: Color
    
    static let defaultMetrics: [ShoppingMetric] = [
        ShoppingMetric(
            title: "Orders today",
            value: "12.4K",
            trend: "+18% vs yesterday",
            icon: "bag.fill",
            iconColor: AppTheme.Colors.primary
        ),
        ShoppingMetric(
            title: "Avg. order value",
            value: "$86.20",
            trend: "+4.5% week over week",
            icon: "dollarsign.arrow.circlepath",
            iconColor: AppTheme.Colors.secondary
        ),
        ShoppingMetric(
            title: "Live viewers",
            value: "35.8K",
            trend: "+9% last hour",
            icon: "person.3.sequence.fill",
            iconColor: AppTheme.Colors.accent
        ),
        ShoppingMetric(
            title: "Conversion rate",
            value: "7.2%",
            trend: "+0.8 pts today",
            icon: "chart.bar.xaxis",
            iconColor: AppTheme.Colors.verificationBlue
        )
    ]
}

enum LiveShoppingFilter: String, CaseIterable, Identifiable {
    case live
    case drops
    case bestSellers
    case newIn
    case creatorPicks
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .live: return "Live"
        case .drops: return "Drops"
        case .bestSellers: return "Bestsellers"
        case .newIn: return "New in"
        case .creatorPicks: return "Creator picks"
        }
    }
    
    var icon: String {
        switch self {
        case .live: return "dot.radiowaves.left.and.right"
        case .drops: return "bolt.fill"
        case .bestSellers: return "chart.line.uptrend.xyaxis"
        case .newIn: return "clock.arrow.circlepath"
        case .creatorPicks: return "person.crop.circle.badge.checkmark"
        }
    }
}

struct ShoppingMetricCard: View {
    let metric: ShoppingMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: metric.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(metric.iconColor)
                .padding(10)
                .background(metric.iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(metric.value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(metric.trend)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(metric.trend.contains("+") ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 0.8)
        )
    }
}

struct QuickFilterPill: View {
    let filter: LiveShoppingFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                Text(filter.title)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? AppTheme.Colors.backgroundSecondary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppTheme.Colors.divider.opacity(0.3) : AppTheme.Colors.divider.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product Detail Sheet
struct ProductDetailSheet: View {
    let product: ShoppingProduct
    @Binding var showARTryOn: Bool
    @Binding var showCheckout: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Product Images
                    TabView {
                        ForEach(0..<3) { i in
                            AsyncImage(url: URL(string: product.imageURL)) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle().fill(AppTheme.Colors.cardBackground)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 400)
                    
                    VStack(spacing: 20) {
                        // Price & Title
                        VStack(alignment: .leading, spacing: 12) {
                            Text(product.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            HStack {
                                Text("$\(String(format: "%.2f", product.price))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                if product.discount > 0 {
                                    Text("$\(product.originalPrice)")
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                        .strikethrough()
                                }
                            }
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", product.rating))
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text("\(product.reviews) reviews")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // AR Try-On Button
                        if product.hasARTryOn {
                            Button {
                                showARTryOn = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arkit")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Try with AR")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        // Buy Now Button
                        Button {
                            showCheckout = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Buy Now - 1-Click Checkout")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - AR Try-On View
struct ARTryOnView: View {
    let product: ShoppingProduct
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Text("AR Try-On View")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("ARKit integration coming soon")
                    .foregroundColor(.white.opacity(0.7))
                
                Button("Close") {
                    dismiss()
                }
                .padding()
            }
        }
    }
}

// MARK: - Live Shopping Stream View
struct LiveShoppingStreamView: View {
    let show: LiveShoppingShow
    
    var body: some View {
        Text("Live Shopping Stream")
            .navigationTitle(show.title)
    }
}

#Preview {
    LiveShoppingView()
}

