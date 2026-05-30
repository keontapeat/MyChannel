// ⚡ PERFORMANCE: Extracted from LiveShoppingView.swift — independent compilation unit.
// All card/component structs compile in parallel with the main LiveShoppingView struct.
import SwiftUI


struct LiveShowHeroCard: View {
    let show: LiveShoppingShow
    @State private var pulse = false
    
    var body: some View {
        NavigationLink(destination: LiveShoppingStreamView(show: show)) {
            VStack(alignment: .leading, spacing: 14) {
                // Thumbnail with overlays
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: show.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        LinearGradient(
                            colors: [
                                Color(hexString: "2C2C2E") ?? .gray,
                                Color(hexString: "1C1C1E") ?? .black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            // Pulsing LIVE badge
                            HStack(spacing: 5) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("LIVE")
                                    .font(.system(size: 11, weight: .heavy))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                                    .shadow(color: .red.opacity(0.5), radius: pulse ? 8 : 4, x: 0, y: 0)
                            )
                            
                            // Viewer count
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text("\(show.viewerCount.abbreviated)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        
                        Text(show.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(14)
                }
                
                // Creator row
                HStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: show.creator.avatarURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Text(String(show.creator.name.prefix(1)))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(AppTheme.Colors.surface, lineWidth: 2))
                            .offset(x: 2, y: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(show.creator.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Streaming now")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Watch button
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Watch")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary.opacity(0.1), in: Capsule())
                }
            }
            .frame(width: 310)
            .padding(14)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Product Highlight Card

struct ProductHighlightCard: View {
    let product: ShoppingProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: product.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.backgroundSecondary)
                            .overlay(
                                Image(systemName: "tshirt.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    VStack(spacing: 6) {
                        if product.hasARTryOn {
                            Image(systemName: "arkit")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(AppTheme.Colors.accent, in: Circle())
                        }
                        
                        if product.discount > 0 {
                            Text("-\(product.discount)%")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppTheme.Colors.error, in: Capsule())
                        }
                    }
                    .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.brand.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .tracking(0.8)
                    
                    Text(product.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if product.discount > 0 {
                            Text("$\(product.originalPrice)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .strikethrough()
                        }
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text(String(format: "%.1f", product.rating))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("(\(product.reviews))")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(12)
            .frame(width: 200)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shopping Category Button

struct ShoppingCategoryButton: View {
    let category: ShoppingCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 54, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(category.color)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 0.5)
                    )
                
                Text(category.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Creator Spotlight Card

struct CreatorSpotlightCard: View {
    let shop: CreatorShop
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: shop.creator.avatarURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.accent, AppTheme.Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Text(String(shop.creator.name.prefix(1)))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.verificationBlue)
                        .background(Circle().fill(AppTheme.Colors.cardBackground).frame(width: 16, height: 16))
                        .offset(x: 2, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(shop.creator.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("\(shop.productCount) products")
                            .font(.system(size: 12, weight: .medium))
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", shop.rating))
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Divider()
                .foregroundColor(AppTheme.Colors.divider.opacity(0.5))
            
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total sales")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("$\(shop.totalSales.formatted(.number.notation(.compactName)))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Button { } label: {
                    Text("Visit Shop")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.textPrimary, in: Capsule())
                }
            }
        }
        .frame(width: 270)
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Flash Deal Card

struct FlashDealCard: View {
    let product: ShoppingProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: product.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.Colors.backgroundSecondary)
                            .overlay(
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    if product.discount > 0 {
                        Text("-\(product.discount)%")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.error, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(5)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        if product.discount > 0 {
                            Text("$\(product.originalPrice)")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .strikethrough()
                        }
                    }
                    
                    // Stock progress bar
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppTheme.Colors.backgroundSecondary)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(product.stockRemaining < 20 ? AppTheme.Colors.error : AppTheme.Colors.success)
                                    .frame(width: geo.size.width * min(CGFloat(product.stockRemaining) / 100.0, 1.0), height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(product.stockRemaining) left — selling fast!")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(product.stockRemaining < 20 ? AppTheme.Colors.error : AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(12)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shopping Metric

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

// MARK: - Live Shopping Filter

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

// MARK: - Metric Card

struct ShoppingMetricCard: View {
    let metric: ShoppingMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: metric.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(metric.iconColor)
                .padding(10)
                .background(metric.iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(metric.value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(metric.trend)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(metric.trend.contains("+") ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Quick Filter Pill

struct QuickFilterPill: View {
    let filter: LiveShoppingFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(filter.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.5), lineWidth: 1)
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
                        ForEach(0..<3, id: \.self) { _ in
                            AsyncImage(url: URL(string: product.imageURL)) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(AppTheme.Colors.backgroundSecondary)
                                    .overlay(
                                        Image(systemName: "tshirt.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    )
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 380)
                    
                    VStack(spacing: 20) {
                        // Price & Title
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text(product.brand.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                    .tracking(1.0)
                                
                                if product.hasARTryOn {
                                    Label("AR", systemImage: "arkit")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppTheme.Colors.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.Colors.accent.opacity(0.12), in: Capsule())
                                }
                            }
                            
                            Text(product.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            HStack(spacing: 8) {
                                Text("$\(String(format: "%.2f", product.price))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                if product.discount > 0 {
                                    Text("$\(product.originalPrice)")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                        .strikethrough()
                                    
                                    Text("Save \(product.discount)%")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppTheme.Colors.success)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.Colors.success.opacity(0.12), in: Capsule())
                                }
                            }
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Image(systemName: i < Int(product.rating) ? "star.fill" : "star")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }
                                    Text(String(format: "%.1f", product.rating))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                                
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text("\(product.reviews) reviews")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            if product.stockRemaining < 30 {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    Text("Only \(product.stockRemaining) left — order soon!")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.error)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Text(product.description)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // AR Try-On Button
                        if product.hasARTryOn {
                            Button {
                                showARTryOn = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arkit")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Try with AR")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.accent, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                            }
                        }
                        
                        // Buy Now Button
                        // 🔥 FIX 2.1/3.1.1: Checkout not yet implemented — show coming soon
                        Button {
                            showCheckout = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Shop Coming Soon")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(true)
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
                            .font(.system(size: 26))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
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
            
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "arkit")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("AR Try-On")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Point your camera to try on\n\(product.name)")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Live Shopping Stream View

struct LiveShoppingStreamView: View {
    let show: LiveShoppingShow
    @Environment(\.dismiss) private var dismiss
    @State private var showProducts = true
    @State private var chatMessage = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Video area
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                // Simulated live stream
                LinearGradient(
                    colors: [
                        Color(hexString: "1a1a2e") ?? .black,
                        Color(hexString: "16213e") ?? .black,
                        Color(hexString: "0f3460") ?? .black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Top overlay controls
                VStack {
                    HStack(spacing: 12) {
                        // Creator info
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(show.creator.name.prefix(1)))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(show.creator.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(show.viewerCount.abbreviated) watching")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        
                        // LIVE badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red, in: Capsule())
                        
                        Spacer()
                        
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Stream title
                    VStack(alignment: .leading, spacing: 8) {
                        Text(show.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(show.description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, showProducts ? 300 : 80)
                }
            }
            
            // Products tray
            if showProducts {
                VStack(spacing: 0) {
                    // Handle bar
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                            Text("Shop this stream")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showProducts.toggle()
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.Colors.backgroundSecondary, in: Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { i in
                                StreamProductCard(index: i)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.Colors.cardBackground)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -8)
                        .ignoresSafeArea(edges: .bottom)
                )
                .transition(.move(edge: .bottom))
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Stream Product Card

struct StreamProductCard: View {
    let index: Int
    
    private var productNames: [String] {
        ["Creator Hoodie", "Logo Tee", "Snapback Cap", "Signature Sneakers"]
    }
    
    private var productPrices: [String] {
        ["$59.99", "$34.99", "$29.99", "$149.99"]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.backgroundSecondary)
                .frame(width: 130, height: 130)
                .overlay(
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                )
            
            Text(productNames[index % productNames.count])
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Text(productPrices[index % productPrices.count])
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Button { } label: {
                Text("Add to Bag")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.textPrimary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(width: 130)
    }
}

#Preview {
    LiveShoppingView()
}

