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
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Banner
                        shoppingHero
                        
                        // Live Shopping Shows
                        liveShowsSection
                        
                        // Featured Products
                        featuredProductsSection
                        
                        // Shop by Category
                        categoriesSection
                        
                        // Creator Shops
                        creatorShopsSection
                        
                        // Flash Sales
                        flashSalesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Live Shopping")
            .navigationBarTitleDisplayMode(.inline)
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
    
    // MARK: - Hero Banner
    private var shoppingHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.2, blue: 0.9),
                            Color(red: 0.8, green: 0.2, blue: 0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 28, weight: .bold))
                    Text("Live Shopping")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Shop live with your favorite creators")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 16) {
                    featureBadge(icon: "camera.fill", text: "AR Try-On")
                    featureBadge(icon: "bolt.fill", text: "Instant Buy")
                    featureBadge(icon: "percent", text: "Flash Sales")
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
    
    // MARK: - Live Shows
    private var liveShowsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    
                    Text("LIVE NOW")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Text("\(viewModel.liveShows.count) shows")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.liveShows) { show in
                        LiveShowCard(show: show)
                    }
                }
            }
        }
    }
    
    // MARK: - Featured Products
    private var featuredProductsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Trending Products")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.featuredProducts) { product in
                    ProductCard(product: product) {
                        selectedProduct = product
                    }
                }
            }
        }
    }
    
    // MARK: - Categories
    private var categoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Shop by Category")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(ShoppingCategory.allCases) { category in
                    CategoryButton(category: category) {
                        // Navigate to category
                    }
                }
            }
        }
    }
    
    // MARK: - Creator Shops
    private var creatorShopsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Creator Shops")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: Text("All Shops")) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.creatorShops) { shop in
                        CreatorShopCard(shop: shop)
                    }
                }
            }
        }
    }
    
    // MARK: - Flash Sales
    private var flashSalesSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Flash Sales")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(viewModel.flashSaleTimeRemaining)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.red)
            }
            
            ForEach(viewModel.flashSaleProducts) { product in
                FlashSaleProductCard(product: product) {
                    selectedProduct = product
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct LiveShowCard: View {
    let show: LiveShoppingShow
    
    var body: some View {
        NavigationLink(destination: LiveShoppingStreamView(show: show)) {
            ZStack(alignment: .topLeading) {
                // Thumbnail
                AsyncImage(url: URL(string: show.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 280, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Live Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.red)
                .clipShape(Capsule())
                .padding(10)
                
                // Viewers count
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                    Text("\(show.viewerCount.abbreviated)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(show.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: show.creator.avatarURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    
                    Text(show.creator.name)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .frame(width: 280)
    }
}

struct ProductCard: View {
    let product: ShoppingProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Product Image
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: product.imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // AR Badge
                    if product.hasARTryOn {
                        Image(systemName: "arkit")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.purple)
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack {
                        if product.discount > 0 {
                            Text("$\(product.originalPrice)")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .strikethrough()
                            
                            Text("\(product.discount)% off")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", product.rating))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("(\(product.reviews))")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct CategoryButton: View {
    let category: ShoppingCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(category.color)
                    .frame(width: 50, height: 50)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
        }
    }
}

struct CreatorShopCard: View {
    let shop: CreatorShop
    
    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: shop.creator.avatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AppTheme.Colors.primary, lineWidth: 3)
            )
            
            VStack(spacing: 4) {
                Text(shop.creator.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text("\(shop.productCount) products")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(width: 120)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FlashSaleProductCard: View {
    let product: ShoppingProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: product.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text("$\(product.originalPrice)")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .strikethrough()
                        
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("\(product.discount)% OFF")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.red)
                            .clipShape(Capsule())
                        
                        Text("\(product.stockRemaining) left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
            )
        }
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

