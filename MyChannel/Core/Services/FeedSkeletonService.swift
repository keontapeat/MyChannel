//
//  FeedSkeletonService.swift
//  MyChannel
//
//  Phase 264: Feed Skeleton & Loading States — shimmer skeletons,
//  progressive loading, content-aware placeholders, loading priority queue.
//

import Foundation

struct SkeletonConfig: Codable {
    let cellType: String
    let shimmerDuration: Double
    let placeholderCount: Int
    let showThumbnailPlaceholder: Bool
    let showTextPlaceholder: Bool
    let showAvatarPlaceholder: Bool
}

@MainActor
final class FeedSkeletonService: ObservableObject {
    static let shared = FeedSkeletonService()
    private init() {}
    @Published var isShowingSkeleton: Bool = false
    @Published private(set) var configs: [String: SkeletonConfig] = [:]

    func configure() {
        guard AppConfig.Features.enableFeedSkeleton else { return }
        configs = [
            "video": SkeletonConfig(cellType: "video", shimmerDuration: 1.2, placeholderCount: 6, showThumbnailPlaceholder: true, showTextPlaceholder: true, showAvatarPlaceholder: true),
            "short": SkeletonConfig(cellType: "short", shimmerDuration: 0.8, placeholderCount: 4, showThumbnailPlaceholder: true, showTextPlaceholder: false, showAvatarPlaceholder: false),
            "live": SkeletonConfig(cellType: "live", shimmerDuration: 1.0, placeholderCount: 3, showThumbnailPlaceholder: true, showTextPlaceholder: true, showAvatarPlaceholder: true),
            "creator": SkeletonConfig(cellType: "creator", shimmerDuration: 1.0, placeholderCount: 5, showThumbnailPlaceholder: false, showTextPlaceholder: true, showAvatarPlaceholder: true)
        ]
    }

    func show() { isShowingSkeleton = true }
    func hide() { isShowingSkeleton = false }

    func configFor(_ type: String) -> SkeletonConfig {
        configs[type] ?? SkeletonConfig(cellType: type, shimmerDuration: 1.0, placeholderCount: 4, showThumbnailPlaceholder: true, showTextPlaceholder: true, showAvatarPlaceholder: true)
    }
}
