//
//  MusicFeaturesAdvanced.swift
//  MyChannel
//
//  Advanced Music Features - Canvas, Concerts, Merch, Discovery, Shazam
//

import SwiftUI
import AVFoundation

// MARK: - =====================================================
// MARK: - CANVAS (Looping Video Backgrounds)
// MARK: - =====================================================

struct CanvasView: View {
    let track: PlaylistTrack
    @State private var currentCanvasIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    // Sample canvas videos (would be real URLs in production)
    let canvasVideos: [String] = [
        "https://example.com/canvas1.mp4",
        "https://example.com/canvas2.mp4",
        "https://example.com/canvas3.mp4"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video background (simulated with animated gradient)
                AnimatedCanvasBackground()
                
                // Content overlay
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("CANVAS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Button {
                            // Share canvas
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Track info at bottom
                    HStack(spacing: 12) {
                        if let url = track.artworkURL {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.2))
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text(track.artist)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Waveform animation
                        HStack(spacing: 2) {
                            ForEach(0..<4) { i in
                                CanvasWaveBar(delay: Double(i) * 0.1)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct AnimatedCanvasBackground: View {
    @State private var phase: CGFloat = 0
    
    private let colors: [Color] = [.purple, .pink, .blue, .indigo, .cyan]
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, size in
                drawEllipses(context: context, size: size, time: time)
            }
            .blur(radius: 60)
            .background(Color.black)
        }
    }
    
    private func drawEllipses(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let centerX = size.width * 0.5 - 150
        let centerY = size.height * 0.5 - 150
        
        for i in 0..<5 {
            let offsetX = CGFloat(i) * 30 + sin(time + Double(i)) * 50
            let offsetY = CGFloat(i) * 20 + cos(time + Double(i)) * 50
            
            let rect = CGRect(
                x: centerX + offsetX,
                y: centerY + offsetY,
                width: 300,
                height: 300
            )
            
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(colors[i].opacity(0.4)))
        }
    }
}

struct CanvasWaveBar: View {
    let delay: Double
    @State private var height: CGFloat = 10
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4).repeatForever().delay(delay)) {
                    height = CGFloat.random(in: 10...25)
                }
            }
    }
}

// MARK: - =====================================================
// MARK: - CONCERTS & EVENTS
// MARK: - =====================================================

struct Concert: Identifiable {
    let id: String
    let artistName: String
    let artistImageURL: String?
    let venueName: String
    let city: String
    let date: Date
    let ticketURL: String
    let priceRange: String
    var isGoing: Bool
    var friendsGoing: Int
}

@MainActor
final class ConcertsService: ObservableObject {
    static let shared = ConcertsService()
    
    @Published var upcomingConcerts: [Concert] = []
    @Published var savedConcerts: [Concert] = []
    @Published var pastConcerts: [Concert] = []
    
    private init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        upcomingConcerts = [
            Concert(
                id: "1",
                artistName: "YN Jay",
                artistImageURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
                venueName: "The Machine Shop",
                city: "Flint, MI",
                date: Date().addingTimeInterval(86400 * 7),
                ticketURL: "https://tickets.com",
                priceRange: "$25 - $50",
                isGoing: false,
                friendsGoing: 12
            ),
            Concert(
                id: "2",
                artistName: "Rio Da Yung OG",
                artistImageURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg",
                venueName: "Saint Andrew's Hall",
                city: "Detroit, MI",
                date: Date().addingTimeInterval(86400 * 14),
                ticketURL: "https://tickets.com",
                priceRange: "$35 - $75",
                isGoing: true,
                friendsGoing: 24
            ),
            Concert(
                id: "3",
                artistName: "RMC Mike",
                artistImageURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg",
                venueName: "The Fillmore",
                city: "Detroit, MI",
                date: Date().addingTimeInterval(86400 * 21),
                ticketURL: "https://tickets.com",
                priceRange: "$30 - $60",
                isGoing: false,
                friendsGoing: 8
            )
        ]
    }
    
    func toggleGoing(_ concert: Concert) {
        if let index = upcomingConcerts.firstIndex(where: { $0.id == concert.id }) {
            upcomingConcerts[index].isGoing.toggle()
            if upcomingConcerts[index].isGoing {
                savedConcerts.append(upcomingConcerts[index])
            } else {
                savedConcerts.removeAll { $0.id == concert.id }
            }
        }
    }
}

struct ConcertsView: View {
    @StateObject private var concertsService = ConcertsService.shared
    @State private var selectedTab: ConcertTab = .upcoming
    
    enum ConcertTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case saved = "Going"
        case past = "Past"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(ConcertTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(.systemBackground))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
            }
            
            // Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    switch selectedTab {
                    case .upcoming:
                        ForEach(concertsService.upcomingConcerts) { concert in
                            ConcertCard(concert: concert)
                        }
                    case .saved:
                        ForEach(concertsService.savedConcerts) { concert in
                            ConcertCard(concert: concert)
                        }
                    case .past:
                        if concertsService.pastConcerts.isEmpty {
                            Text("No past concerts")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Concerts")
    }
}

struct ConcertCard: View {
    let concert: Concert
    @StateObject private var concertsService = ConcertsService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with artist
            HStack(spacing: 12) {
                if let url = concert.artistImageURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color(.systemGray5))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(concert.artistName)
                        .font(.system(size: 18, weight: .bold))
                    Text(formatDate(concert.date))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            
            Divider().padding(.horizontal, 16)
            
            // Venue info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(concert.venueName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text(concert.city)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(concert.priceRange)
                        .font(.system(size: 14, weight: .semibold))
                    if concert.friendsGoing > 0 {
                        Text("\(concert.friendsGoing) friends going")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(16)
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    concertsService.toggleGoing(concert)
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: concert.isGoing ? "checkmark" : "calendar.badge.plus")
                        Text(concert.isGoing ? "Going" : "Interested")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(concert.isGoing ? .white : AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(concert.isGoing ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button {
                    // Open ticket URL
                } label: {
                    Text("Get Tickets")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - =====================================================
// MARK: - MERCH STORE
// MARK: - =====================================================

struct MerchItem: Identifiable {
    let id: String
    let artistName: String
    let name: String
    let description: String
    let price: Double
    let imageURL: String?
    let sizes: [String]?
    let category: MerchCategory
    var isFavorite: Bool
    
    enum MerchCategory: String, CaseIterable {
        case all = "All"
        case clothing = "Clothing"
        case accessories = "Accessories"
        case vinyl = "Vinyl"
        case posters = "Posters"
    }
}

struct MerchStoreView: View {
    @State private var selectedCategory: MerchItem.MerchCategory = .all
    @State private var merchItems: [MerchItem] = [
        MerchItem(id: "1", artistName: "YN Jay", name: "Coochie Chronicles Tee", description: "Official tour merch", price: 35.00, imageURL: nil, sizes: ["S", "M", "L", "XL", "XXL"], category: .clothing, isFavorite: false),
        MerchItem(id: "2", artistName: "Rio Da Yung OG", name: "Flint Made Hoodie", description: "Premium heavyweight hoodie", price: 65.00, imageURL: nil, sizes: ["S", "M", "L", "XL"], category: .clothing, isFavorite: true),
        MerchItem(id: "3", artistName: "RMC Mike", name: "810 Chain", description: "Gold plated pendant", price: 120.00, imageURL: nil, sizes: nil, category: .accessories, isFavorite: false),
        MerchItem(id: "4", artistName: "YN Jay", name: "Coochie Chronicles Vinyl", description: "Limited edition pressing", price: 30.00, imageURL: nil, sizes: nil, category: .vinyl, isFavorite: false),
        MerchItem(id: "5", artistName: "Flint Artists", name: "810 Poster Set", description: "3 poster bundle", price: 25.00, imageURL: nil, sizes: nil, category: .posters, isFavorite: false)
    ]
    @State private var cartItems: [String] = []
    @State private var showCart: Bool = false
    
    var filteredItems: [MerchItem] {
        if selectedCategory == .all {
            return merchItems
        }
        return merchItems.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MerchItem.MerchCategory.allCases, id: \.self) { category in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = category
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 14, weight: selectedCategory == category ? .semibold : .regular))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == category ? AppTheme.Colors.primary : Color(.systemGray6))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            
            // Items grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredItems) { item in
                        MerchItemCard(item: item) {
                            cartItems.append(item.id)
                            HapticManager.shared.notification(type: .success)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Merch")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCart = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bag")
                            .font(.system(size: 18))
                        
                        if !cartItems.isEmpty {
                            Text("\(cartItems.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(.red))
                                .offset(x: 8, y: -4)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCart) {
            MerchCartView(cartItems: cartItems, allItems: merchItems)
        }
    }
}

struct MerchItemCard: View {
    let item: MerchItem
    let onAddToCart: () -> Void
    @State private var isFavorite: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: iconForCategory(item.category))
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                // Favorite button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isFavorite.toggle()
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(isFavorite ? .red : .gray)
                                .padding(8)
                                .background(Circle().fill(Color(.systemBackground)))
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(height: 160)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                
                HStack {
                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Spacer()
                    
                    Button {
                        onAddToCart()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func iconForCategory(_ category: MerchItem.MerchCategory) -> String {
        switch category {
        case .all: return "bag"
        case .clothing: return "tshirt"
        case .accessories: return "watch"
        case .vinyl: return "opticaldisc"
        case .posters: return "photo"
        }
    }
}

struct MerchCartView: View {
    let cartItems: [String]
    let allItems: [MerchItem]
    @Environment(\.dismiss) private var dismiss
    
    var itemsInCart: [MerchItem] {
        cartItems.compactMap { cartId in
            allItems.first { $0.id == cartId }
        }
    }
    
    var total: Double {
        itemsInCart.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if itemsInCart.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bag")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Your bag is empty")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Add some merch to get started")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                } else {
                    List {
                        ForEach(itemsInCart) { item in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "tshirt")
                                            .foregroundColor(.gray)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(item.artistName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("$\(item.price, specifier: "%.2f")")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                    
                    // Checkout section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Total")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Text("$\(total, specifier: "%.2f")")
                                .font(.system(size: 20, weight: .bold))
                        }
                        
                        Button {
                            HapticManager.shared.notification(type: .success)
                        } label: {
                            Text("Checkout")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                }
                
                Spacer()
            }
            .navigationTitle("Your Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - =====================================================
// MARK: - DISCOVER WEEKLY / DAILY MIX
// MARK: - =====================================================

struct DiscoverView: View {
    @State private var selectedMix: MixType = .daily
    
    enum MixType: String, CaseIterable {
        case daily = "Daily Mix"
        case weekly = "Discover Weekly"
        case release = "Release Radar"
        case flint = "810 Mix"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Featured mix card
                featuredMixCard
                
                // Mix types
                VStack(alignment: .leading, spacing: 16) {
                    Text("Made for You")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(MixType.allCases, id: \.self) { mix in
                                MixCard(mix: mix, isSelected: selectedMix == mix) {
                                    selectedMix = mix
                                    HapticManager.shared.impact(style: .medium)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Today's picks
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Picks")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(0..<10) { i in
                            DiscoverTrackRow(index: i + 1)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("For You")
    }
    
    private var featuredMixCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [.purple, .blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text("DISCOVER WEEKLY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Your weekly mixtape of fresh music")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Updated every Monday")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white))
                    }
                    
                    Button {
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
}

struct MixCard: View {
    let mix: DiscoverView.MixType
    let isSelected: Bool
    let action: () -> Void
    
    var gradientColors: [Color] {
        switch mix {
        case .daily: return [.orange, .pink]
        case .weekly: return [.purple, .blue]
        case .release: return [.green, .teal]
        case .flint: return [.red, .orange]
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppTheme.Colors.primary : .clear, lineWidth: 3)
                )
                
                Text(mix.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Updated daily")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DiscoverTrackRow: View {
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Track \(index)")
                    .font(.system(size: 15))
                Text("Artist Name")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - =====================================================
// MARK: - SHAZAM INTEGRATION
// MARK: - =====================================================

struct ShazamView: View {
    @State private var isListening: Bool = false
    @State private var identifiedTrack: ShazamResult? = nil
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss
    
    struct ShazamResult {
        let title: String
        let artist: String
        let artworkURL: String?
        let appleMusicURL: String?
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mainContent
            resultOverlay
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 30) {
            Spacer()
            shazamButton
            statusText
            Spacer()
            cancelButton
        }
    }
    
    private var shazamButton: some View {
        ZStack {
            pulseRings
            mainListenButton
        }
    }
    
    @ViewBuilder
    private var pulseRings: some View {
        if isListening {
            ForEach(0..<3, id: \.self) { i in
                let scale = pulseScale + CGFloat(i) * 0.2
                let opacity = 1.5 - scale / 2
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
    }
    
    private var mainListenButton: some View {
        Button {
            toggleListening()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .shadow(color: .blue.opacity(0.5), radius: 20)
                
                Image(systemName: "waveform")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var statusText: some View {
        Text(isListening ? "Listening..." : "Tap to identify music")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
    }
    
    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Cancel")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Capsule().fill(.white.opacity(0.1)))
        }
        .padding(.bottom, 40)
    }
    
    @ViewBuilder
    private var resultOverlay: some View {
        if let track = identifiedTrack {
            ShazamResultView(result: track) {
                identifiedTrack = nil
            }
        }
    }
    
    private func toggleListening() {
        isListening.toggle()
        HapticManager.shared.impact(style: .medium)
        
        if isListening {
            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
            
            // Simulate finding a song after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isListening = false
                    pulseScale = 1.0
                    identifiedTrack = ShazamResult(
                        title: "Coochie",
                        artist: "YN Jay",
                        artworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
                        appleMusicURL: nil
                    )
                }
                HapticManager.shared.notification(type: .success)
            }
        } else {
            pulseScale = 1.0
        }
    }
}

struct ShazamResultView: View {
    let result: ShazamView.ShazamResult
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 20) {
                if let url = result.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray5))
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 20)
                }
                
                Text(result.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(result.artist)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 16) {
                    Button {
                        // Open in Apple Music
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white))
                    }
                    
                    Button {
                        // Add to library
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                    
                    Button {
                        // Share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
            
            Button {
                onDismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 30)
            
            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// MARK: - =====================================================
// MARK: - COLLABORATIVE PLAYLISTS
// MARK: - =====================================================

struct CollaborativePlaylistView: View {
    @State var playlist: UserPlaylist
    @State private var showInvite: Bool = false
    @StateObject private var playlistService = PlaylistService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Collaborators header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Collaborators")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button {
                            showInvite = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Invite")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    // Collaborator avatars
                    HStack(spacing: -10) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("\(["M", "S", "J", "A"][i])")
                                        .font(.system(size: 16, weight: .semibold))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemBackground), lineWidth: 3)
                                )
                        }
                        
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text("+3")
                                    .font(.system(size: 14, weight: .semibold))
                            )
                    }
                    
                    Text("\(7) people can edit this playlist")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Activity feed
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.system(size: 18, weight: .semibold))
                    
                    VStack(spacing: 0) {
                        CollabActivityRow(name: "Mike", action: "added", trackName: "Coochie", time: "2m ago")
                        CollabActivityRow(name: "Sarah", action: "added", trackName: "Flint Flow", time: "1h ago")
                        CollabActivityRow(name: "James", action: "removed", trackName: "Old Song", time: "3h ago")
                    }
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Toggle("Allow anyone with link to add songs", isOn: .constant(false))
                        .font(.system(size: 15))
                    
                    Toggle("Notify when songs are added", isOn: .constant(true))
                        .font(.system(size: 15))
                }
            }
            .padding(20)
        }
        .navigationTitle("Collaborate")
        .sheet(isPresented: $showInvite) {
            InviteCollaboratorsSheet()
        }
    }
}

struct CollabActivityRow: View {
    let name: String
    let action: String
    let trackName: String
    let time: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) \(action) \"\(trackName)\"")
                    .font(.system(size: 14))
                Text(time)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct InviteCollaboratorsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search friends", text: $searchText)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)
                
                // Share link
                VStack(spacing: 12) {
                    Text("Or share invite link")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button {
                        // Copy link
                        HapticManager.shared.notification(type: .success)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text("Copy Link")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(AppTheme.Colors.primary, lineWidth: 1.5)
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Invite Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

