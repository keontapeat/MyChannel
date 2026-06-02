//
//  LiveShoppingView.swift
//  MyChannel
//
//  LIVE SHOPPING NETWORK - Premium YouTube-style merch selling
//  AR try-on, instant checkout, creator commissions
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct LiveShoppingView: View {
    @StateObject private var viewModel = LiveShoppingViewModel()
    @State private var selectedProduct: ShoppingProduct?
    @State private var showARTryOn = false
    @State private var showCheckout = false
    @State private var selectedFilter: LiveShoppingFilter = .live
    @State private var animateMetrics = false
    @State private var showNotifications = false
    @State private var showSearch = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // 🔥 FIX: No nested NavigationStack — this view is always pushed from
        // ProfileView's stack. A second stack rendered its own nav bar, which
        // produced the double back-button (chevron) seen on the feature card.
        // We now rely on the parent stack's automatic back button.
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Premium Header
                    liveShoppingHeader

                    // Live Now Hero
                    heroSection
                        .padding(.top, 8)

                    // Real-time Metrics Dashboard
                    metricsSection
                        .padding(.top, 24)

                    // Quick Filters
                    filtersSection
                        .padding(.top, 28)

                    // Trending Merch
                    trendingProductsSection
                        .padding(.top, 24)

                    // Shop by Category
                    categoriesSection
                        .padding(.top, 28)

                    // Creator Spotlight
                    creatorSpotlightSection
                        .padding(.top, 28)

                    // Flash Deals
                    flashDealsSection
                        .padding(.top, 28)

                    // Go Live CTA for creators
                    goLiveCTA
                        .padding(.top, 32)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Leading back button is provided automatically by the parent
            // NavigationStack — do not add a second one here.
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button { showNotifications = true } label: {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                    .accessibilityLabel("Shopping notifications")

                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                    .accessibilityLabel("Search merch")
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailSheet(product: product, showARTryOn: $showARTryOn, showCheckout: $showCheckout)
        }
        .fullScreenCover(isPresented: $showARTryOn) {
            if let product = selectedProduct {
                ARTryOnView(product: product)
            }
        }
        .sheet(isPresented: $showSearch) {
            LiveShoppingSearchView(viewModel: viewModel) { product in
                showSearch = false
                selectedProduct = product
            }
        }
        .sheet(isPresented: $showNotifications) {
            LiveShoppingNotificationsView()
        }
        .onAppear {
            Task {
                await viewModel.loadLiveShops()
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                animateMetrics = true
            }
        }
        .refreshable {
            await viewModel.loadLiveShops()
        }
    }
    
    // MARK: - Premium Header
    private var liveShoppingHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.premiumGradient)
                
                Text("Live Shopping")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Sell merch live to your audience")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(Color.red.opacity(0.4))
                                .frame(width: 16, height: 16)
                        )
                    Text("Live now")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Text("\(viewModel.liveShows.count) shows")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(AppTheme.Colors.surface, in: Capsule())
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.liveShows) { show in
                        LiveShowHeroCard(show: show)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Metrics Dashboard
    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(viewModel.metrics.enumerated()), id: \.element.id) { index, metric in
                ShoppingMetricCard(metric: metric)
                    .opacity(animateMetrics ? 1 : 0)
                    .offset(y: animateMetrics ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08), value: animateMetrics)
            }
        }
    }
    
    // MARK: - Filters
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Discover")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LiveShoppingFilter.allCases) { filter in
                        QuickFilterPill(
                            filter: filter,
                            isSelected: filter == selectedFilter
                        ) {
                            withAnimation(AppTheme.AnimationPresets.spring) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Products
    private var trendingProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trending merch")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Curated drops updated hourly")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button {
                    // TODO: navigate to full catalog
                } label: {
                    HStack(spacing: 4) {
                        Text("View all")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.featuredProducts) { product in
                        ProductHighlightCard(product: product) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Categories
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shop by category")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(ShoppingCategory.allCases) { category in
                    ShoppingCategoryButton(category: category) {
                        // TODO: route to category storefront
                    }
                }
            }
        }
    }
    
    // MARK: - Creator Spotlight
    private var creatorSpotlightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Creator spotlight")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button {
                    // TODO: navigate
                } label: {
                    HStack(spacing: 4) {
                        Text("Browse all")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.creatorShops) { shop in
                        CreatorSpotlightCard(shop: shop)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Flash Deals
    private var flashDealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Flash deals")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                    Text(viewModel.flashSaleTimeRemaining)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(AppTheme.Colors.error)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.Colors.error.opacity(0.1), in: Capsule())
            }
            
            VStack(spacing: 10) {
                ForEach(viewModel.flashSaleProducts) { product in
                    FlashDealCard(product: product) {
                        selectedProduct = product
                    }
                }
            }
        }
    }
    
    // MARK: - Go Live CTA
    private var goLiveCTA: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.premiumGradient)
                
                Text("Start selling live")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Go live and showcase your merch to fans in real-time")
                    .font(AppTheme.Typography.footnote)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button {
                // TODO: launch go-live flow
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Go Live Now")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.premiumGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 0.8)
        )
    }

}

// ⚡ All card/component structs extracted to LiveShoppingComponents.swift
