//
//  ThumbnailMarketplaceView.swift
//  MyChannel
//
//  Thumbnail Template Marketplace - Buy & Sell Templates
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct ThumbnailMarketplaceView: View {
    @StateObject private var viewModel = ThumbnailMarketplaceViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showUploadTemplate = false
    @State private var selectedCategory: TemplateCategory = .all
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Banner
                        heroBanner
                        
                        // Creator Revenue Stats
                        if let user = appState.currentUser, viewModel.userIsCreator {
                            creatorRevenueCard
                        }
                        
                        // Category Filter
                        categoryFilter
                        
                        // Featured Templates
                        featuredSection
                        
                        // All Templates Grid
                        templatesGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Template Marketplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showUploadTemplate = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Sell")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showUploadTemplate) {
            UploadTemplateView()
                .environmentObject(appState)
        }
        .onAppear {
            Task {
                await viewModel.loadTemplates()
            }
        }
    }
    
    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.2, blue: 0.8),
                            Color(red: 0.2, green: 0.1, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                    Text("Template Marketplace")
                        .font(.system(size: 24, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Create, sell & buy viral thumbnail templates")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("90% revenue share for creators")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Creator Revenue Card
    private var creatorRevenueCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Template Sales")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Last 30 days")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                NavigationLink(destination: TemplateAnalyticsView()) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            HStack(spacing: 16) {
                revenueStatCard(
                    title: "Revenue",
                    value: "$\(viewModel.creatorRevenue)",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                revenueStatCard(
                    title: "Sales",
                    value: "\(viewModel.templateSales)",
                    icon: "cart.fill",
                    color: .blue
                )
                
                revenueStatCard(
                    title: "Templates",
                    value: "\(viewModel.myTemplatesCount)",
                    icon: "photo.stack.fill",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func revenueStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TemplateCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        Task {
                            await viewModel.filterByCategory(category)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Featured Section
    private var featuredSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Featured")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Top selling templates this week")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredTemplates) { template in
                        FeaturedTemplateCard(template: template)
                    }
                }
            }
        }
    }
    
    // MARK: - Templates Grid
    private var templatesGrid: some View {
        VStack(spacing: 16) {
            HStack {
                Text("All Templates")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.templates.count) templates")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.templates) { template in
                    NavigationLink(destination: TemplateDetailView(template: template)) {
                        MarketplaceTemplateCard(template: template)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let category: TemplateCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct FeaturedTemplateCard: View {
    let template: ThumbnailTemplateProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Template Preview
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: template.previewURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Featured Badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("FEATURED")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange)
                .clipShape(Capsule())
                .padding(10)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                HStack {
                    AsyncImage(url: URL(string: template.creator.profileImageURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                    
                    Text(template.creator.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", template.price))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", template.rating))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("\(template.salesCount) sales")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .frame(width: 240)
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct MarketplaceTemplateCard: View {
    let template: ThumbnailTemplateProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Preview
            AsyncImage(url: URL(string: template.previewURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.cardBackground)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", template.rating))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", template.price))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
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

// MARK: - Template Detail View
struct TemplateDetailView: View {
    let template: ThumbnailTemplateProduct
    @State private var showPurchaseSheet = false
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preview
                AsyncImage(url: URL(string: template.previewURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.cardBackground)
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 20)
                
                // Info
                VStack(alignment: .leading, spacing: 16) {
                    Text(template.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    // Creator Info
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: template.creator.profileImageURL)) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(AppTheme.Colors.cardBackground)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.creator.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Template Creator")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Stats
                    HStack(spacing: 20) {
                        statItem(icon: "star.fill", value: String(format: "%.1f", template.rating), label: "Rating")
                        statItem(icon: "cart.fill", value: "\(template.salesCount)", label: "Sales")
                        statItem(icon: "heart.fill", value: "\(template.likesCount)", label: "Likes")
                    }
                    
                    Divider()
                    
                    // Description
                    Text("About this template")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(template.description)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                
                // Purchase Button
                Button {
                    showPurchaseSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Buy for $\(String(format: "%.2f", template.price))")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(AppTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseTemplateSheet(template: template)
        }
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(value)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(AppTheme.Colors.primary)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Upload Template View
struct UploadTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UploadTemplateViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Template Preview
                    if let image = viewModel.templateImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        Button {
                            viewModel.showImagePicker = true
                        } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text("Upload Template")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.Colors.divider.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                        }
                    }
                    
                    VStack(spacing: 16) {
                        ProfessionalInputField(
                            title: "Template Name",
                            text: $viewModel.name,
                            placeholder: "Enter template name",
                            icon: "textformat",
                            isRequired: true,
                            maxLength: 60
                        )
                        
                        ProfessionalTextEditor(
                            title: "Description",
                            text: $viewModel.description,
                            placeholder: "Describe your template",
                            icon: "text.bubble",
                            maxLength: 500
                        )
                        
                        // Category Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Picker("Category", selection: $viewModel.category) {
                                ForEach(TemplateCategory.allCases.filter { $0 != .all }) { category in
                                    Text(category.rawValue).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(14)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Price Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Price (USD)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            HStack {
                                Text("$")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                TextField("9.99", value: $viewModel.price, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                            .padding(14)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text("You'll earn 90% ($\(String(format: "%.2f", viewModel.price * 0.9))) per sale")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.uploadTemplate()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if viewModel.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            
                            Text(viewModel.isUploading ? "Uploading..." : "List Template")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!viewModel.isValid || viewModel.isUploading)
                    .opacity(viewModel.isValid ? 1.0 : 0.5)
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Sell Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Purchase Sheet
struct PurchaseTemplateSheet: View {
    let template: ThumbnailTemplateProduct
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Template Preview
                AsyncImage(url: URL(string: template.previewURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Purchase Summary")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text(template.name)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Template Price")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", template.price))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    HStack {
                        Text("Platform Fee (10%)")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", template.price * 0.1))")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", template.price))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .padding(20)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button {
                    isPurchasing = true
                    Task {
                        await purchaseTemplate()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Text(isPurchasing ? "Processing..." : "Confirm Purchase")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(AppTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func purchaseTemplate() async {
        // Implement purchase logic with Stripe/payment processor
        print("💳 Purchasing template: \(template.name) for $\(template.price)")
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        print("✅ Purchase complete!")
    }
}

// MARK: - Template Analytics View
struct TemplateAnalyticsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Template Analytics Coming Soon")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .padding(20)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Analytics")
    }
}

#Preview {
    ThumbnailMarketplaceView()
        .environmentObject(AppState())
}

