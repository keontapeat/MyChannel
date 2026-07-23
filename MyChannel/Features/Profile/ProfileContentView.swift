//
//  ProfileContentView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UIKit

enum VideoBulkAction: CaseIterable {
    case edit
    case visibility
    case playlist
    case download
    case share
    case delete
    
    var title: String {
        switch self {
        case .edit: return "Edit"
        case .visibility: return "Visibility"
        case .playlist: return "Playlist"
        case .download: return "Download"
        case .share: return "Share"
        case .delete: return "Delete"
        }
    }
    
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .visibility: return "eye"
        case .playlist: return "text.badge.plus"
        case .download: return "arrow.down.circle"
        case .share: return "square.and.arrow.up"
        case .delete: return "trash.fill"
        }
    }
    
    var tint: Color {
        switch self {
        case .edit, .visibility, .playlist, .download, .share:
            return AppTheme.Colors.textPrimary
        case .delete:
            return AppTheme.Colors.error
        }
    }
    
    var isDestructive: Bool {
        self == .delete
    }
}

// MARK: - Video Management Context
struct VideoManagementContext {
    let isManaging: Binding<Bool>
    let selectedIDs: Binding<Set<String>>
    let onToggleSelection: (String) -> Void
    let onSetSelections: ([String]) -> Void
    let onAction: (VideoBulkAction) -> Void
    let onExit: () -> Void
    let isDeleting: Bool
}

// MARK: - Safe Profile Content View
struct SafeProfileContentView: View {
    @Binding var selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    var onLoadMore: (() async -> Void)? = nil // ⚡ PERFORMANCE: Pagination callback
    var hasMoreVideos: Bool = false // ⚡ PERFORMANCE: Pagination state
    var isLoadingMore: Bool = false // ⚡ PERFORMANCE: Loading state
    var isOwnProfile: Bool = false
    var videoManagementContext: VideoManagementContext? = nil
    var isLoadingVideos: Bool = false // ⚡ PERFORMANCE: Initial loading state for skeleton
    
    var body: some View {
        SafeViewWrapper {
            ProfileContentView(
                selectedTab: $selectedTab,
                user: user,
                videos: videos,
                onLoadMore: onLoadMore,
                hasMoreVideos: hasMoreVideos,
                isLoadingMore: isLoadingMore,
                isOwnProfile: isOwnProfile,
                videoManagementContext: videoManagementContext,
                isLoadingVideos: isLoadingVideos
            )
        } fallback: {
            ProfileContentFallback(selectedTab: selectedTab)
        }
    }
}

// MARK: - Profile Content View
struct ProfileContentView: View {
    @Binding var selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    var onLoadMore: (() async -> Void)? = nil // ⚡ PERFORMANCE: Pagination callback
    var hasMoreVideos: Bool = false // ⚡ PERFORMANCE: Pagination state
    var isLoadingMore: Bool = false // ⚡ PERFORMANCE: Loading state
    let isOwnProfile: Bool
    var videoManagementContext: VideoManagementContext? = nil
    var isLoadingVideos: Bool = false // ⚡ PERFORMANCE: Initial loading state for skeleton
    
    var body: some View {
        LazyVStack(spacing: 0) {
            switch selectedTab {

            case .videos:
                ProfileVideosView(
                    videos: videos,
                    user: user,
                    isOwnProfile: isOwnProfile,
                    onLoadMore: onLoadMore,
                    hasMoreVideos: hasMoreVideos,
                    isLoadingMore: isLoadingMore,
                    managementContext: videoManagementContext,
                    isLoadingVideos: isLoadingVideos
                )
            case .flicks:
                ProfileShortsView(videos: videos, user: user)
            case .live:
                ProfileLiveView(videos: videos, user: user)
            case .playlists:
                ProfilePlaylistsView(user: user)
            case .downloads:
                ProfileDownloadsTabView()
            case .community:
                ProfileCommunityView(user: user)
            case .about:
                ProfileAboutView(user: user)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}



































// MARK: - Content Fallback
struct ProfileContentFallback: View {
    let selectedTab: ProfileTab
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab.iconName)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Content Unavailable")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("Unable to load \(selectedTab.title.lowercased())")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .padding(40)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}











struct StockVideoBannersCarousel: View {
    let banners: [StockVideoBanner]
    @State private var current: Int = 0
    
    var body: some View {
        TabView(selection: $current) {
            ForEach(Array(banners.enumerated()), id: \.offset) { idx, banner in
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: banner.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.Colors.textTertiary.opacity(0.15))
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(banner.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(banner.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 150)
    }
}



struct UIKitProfileFilterRow: UIViewRepresentable {
    @Binding var visibilityFilter: VideoVisibilityFilter
    @Binding var typeFilter: VideoTypeFilter
    
    private var items: [ProfileFilterItem] {
        VideoVisibilityFilter.allCases.map { .visibility($0) } + VideoTypeFilter.allCases.map { .type($0) }
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(ProfileFilterCollectionCell.self, forCellWithReuseIdentifier: ProfileFilterCollectionCell.reuseIdentifier)
        return collectionView
    }
    
    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        collectionView.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var parent: UIKitProfileFilterRow
        
        init(parent: UIKitProfileFilterRow) {
            self.parent = parent
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.items.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProfileFilterCollectionCell.reuseIdentifier, for: indexPath) as? ProfileFilterCollectionCell else {
                return UICollectionViewCell()
            }
            let item = parent.items[indexPath.item]
            cell.configure(
                title: item.title,
                iconName: item.icon,
                isSelected: item.isSelected(visibility: parent.visibilityFilter, type: parent.typeFilter)
            )
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let item = parent.items[indexPath.item]
            switch item {
            case .visibility(let filter):
                parent.visibilityFilter = filter
            case .type(let filter):
                parent.typeFilter = filter
            }
            HapticManager.shared.impact(style: .light)
            collectionView.reloadData()
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let item = parent.items[indexPath.item]
            let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            let textWidth = item.title.size(withAttributes: [.font: font]).width
            let iconWidth: CGFloat = item.icon == nil ? 0 : 18
            return CGSize(width: ceil(textWidth + iconWidth + 28), height: 34)
        }
    }
}

enum ProfileFilterItem {
    case visibility(VideoVisibilityFilter)
    case type(VideoTypeFilter)
    
    var title: String {
        switch self {
        case .visibility(let filter): return filter.title
        case .type(let filter): return filter.title
        }
    }
    
    var icon: String? {
        switch self {
        case .visibility(let filter): return filter.icon
        case .type(let filter): return filter.icon
        }
    }
    
    func isSelected(visibility: VideoVisibilityFilter, type: VideoTypeFilter) -> Bool {
        switch self {
        case .visibility(let filter): return visibility == filter
        case .type(let filter): return type == filter
        }
    }
}

private final class ProfileFilterCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "ProfileFilterCollectionCell"
    
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        titleLabel.text = nil
    }
    
    func configure(title: String, iconName: String?, isSelected: Bool) {
        iconView.image = iconName.flatMap { UIImage(systemName: $0) }
        iconView.isHidden = iconName == nil
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let textColor = isSelected ? UIColor.white : UIColor(AppTheme.Colors.textPrimary)
        iconView.tintColor = textColor
        titleLabel.textColor = textColor
        contentView.backgroundColor = isSelected ? UIColor(AppTheme.Colors.primary) : UIColor(AppTheme.Colors.surface)
        contentView.layer.borderColor = UIColor(AppTheme.Colors.divider.opacity(isSelected ? 0 : 0.3)).cgColor
        contentView.layer.borderWidth = 1
        accessibilityLabel = title
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    }
    
    private func setup() {
        isAccessibilityElement = true
        contentView.layer.cornerRadius = 17
        contentView.layer.masksToBounds = true
        
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 12).isActive = true
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
}







struct StockVideoBanner: Identifiable {
    let id = UUID()
    let imageURL: String
    let title: String
    let subtitle: String
    
    static let defaults: [StockVideoBanner] = [
        .init(
            imageURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80",
            title: "Travel Vlog",
            subtitle: "Explore the world in 4K"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80",
            title: "Cinematic Nature",
            subtitle: "Relaxing landscapes and skies"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1518770660439-b723cf961d3e?w=1600&q=80",
            title: "Tech Reviews",
            subtitle: "Latest gadgets and gear"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1495195134817-aeb325a55b65?w=1600&q=80",
            title: "Cooking Series",
            subtitle: "Delicious recipes made simple"
        )
    ]
}







enum ViewVelocity {
    case accelerating, stable, decelerating

    var label: String {
        switch self {
        case .accelerating: return "Trending Up"
        case .stable: return "Stable"
        case .decelerating: return "Slowing"
        }
    }

    var icon: String {
        switch self {
        case .accelerating: return "arrow.up.forward"
        case .stable: return "minus"
        case .decelerating: return "arrow.down.forward"
        }
    }

    var color: Color {
        switch self {
        case .accelerating: return .green
        case .stable: return .gray
        case .decelerating: return .orange
        }
    }
}

enum PerformanceTier: CaseIterable {
    case viral, trending, performing, standard, new

    var label: String {
        switch self {
        case .viral: return "Viral"
        case .trending: return "Trending"
        case .performing: return "Performing"
        case .standard: return "Active"
        case .new: return "New"
        }
    }

    var icon: String {
        switch self {
        case .viral: return "flame.fill"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .performing: return "arrow.up.circle.fill"
        case .standard: return "checkmark.circle.fill"
        case .new: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .viral: return .orange
        case .trending: return .green
        case .performing: return .blue
        case .standard: return .gray
        case .new: return .purple
        }
    }

    static func forViewCount(_ count: Int) -> PerformanceTier {
        switch count {
        case 1_000_000...: return .viral
        case 100_000..<1_000_000: return .trending
        case 10_000..<100_000: return .performing
        case 100..<10_000: return .standard
        default: return .new
        }
    }
}





// MARK: - Pinned Card Thumbnail
struct PinnedCardThumb: View {
    let urls: [URL]
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geo in
            if urls.isEmpty {
                placeholder
            } else {
                AsyncImage(url: urls[currentIndex]) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .failure:
                        if currentIndex < urls.count - 1 {
                            Color.clear.onAppear { currentIndex += 1 }
                        } else {
                            placeholder
                        }
                    case .empty:
                        shimmer
                    @unknown default:
                        placeholder
                    }
                }
            }
        }
        .clipped()
    }
    
    private var placeholder: some View {
        ZStack {
            AppTheme.Colors.surface
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.Colors.textTertiary.opacity(0.5))
        }
    }
    
    private var shimmer: some View {
        AppTheme.Colors.surface
            .overlay(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.surface,
                        AppTheme.Colors.surface.opacity(0.5),
                        AppTheme.Colors.surface
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

















#Preview("Profile Videos Layout Toggle") {
    ScrollView {
        ProfileVideosView(
            videos: Array(Video.sampleVideos.prefix(8)),
            user: User.sampleUsers.first ?? .defaultUser,
            isOwnProfile: true
        )
    }
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.light)
}

#Preview("🔥 Premium Pinned Section") {
    ScrollView {
        PremiumPinnedSection(videos: Array(Video.sampleVideos.prefix(3)), userId: "preview_user")
    }
    .background(AppTheme.Colors.background)
    .environmentObject(AppState())
}