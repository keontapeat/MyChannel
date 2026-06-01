import SwiftUI
import UIKit

struct FeaturedUIKitCarousel: UIViewRepresentable {
    let videos: [Video]
    @Binding var selectedIndex: Int
    let isCompact: Bool
    let allowLiveInPreview: Bool
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void
    var onUserInteraction: ((Bool) -> Void)? = nil
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.reuseID)
        return collectionView
    }
    
    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        
        let currentVideoIds = videos.map { $0.id }
        if context.coordinator.lastVideoIds != currentVideoIds {
            context.coordinator.lastVideoIds = currentVideoIds
            collectionView.reloadData()
        }
        
        let clampedIndex = min(max(selectedIndex, 0), max(videos.count - 1, 0))
        if videos.indices.contains(clampedIndex), collectionView.numberOfItems(inSection: 0) > clampedIndex {
            let targetX = CGFloat(clampedIndex) * collectionView.bounds.width
            let currentX = collectionView.contentOffset.x
            if abs(currentX - targetX) > 1 {
                if !collectionView.isDragging && !collectionView.isTracking {
                    collectionView.scrollToItem(at: IndexPath(item: clampedIndex, section: 0), at: .centeredHorizontally, animated: true)
                }
            }
        }
    }
    
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
        static let reuseID = "FeaturedUIKitCarouselCell"
        var parent: FeaturedUIKitCarousel
        var lastVideoIds: [String] = []
        
        init(parent: FeaturedUIKitCarousel) {
            self.parent = parent
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.videos.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseID, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                let video = parent.videos[indexPath.item]
                FeaturedHeroCard(
                    video: video,
                    isCompact: parent.isCompact,
                    isActive: indexPath.item == parent.selectedIndex,
                    allowLiveInPreview: parent.allowLiveInPreview,
                    onPlay: { self.parent.onPlayVideo(video) },
                    onAddToList: { self.parent.onAddToList(video) }
                )
            }
            .margins(.all, 0)
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            collectionView.bounds.size
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.onUserInteraction?(true)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateSelectedIndex(from: scrollView)
                parent.onUserInteraction?(false)
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateSelectedIndex(from: scrollView)
            parent.onUserInteraction?(false)
        }
        
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            updateSelectedIndex(from: scrollView)
        }
        
        private func updateSelectedIndex(from scrollView: UIScrollView) {
            guard scrollView.bounds.width > 0 else { return }
            let index = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
            if parent.videos.indices.contains(index), parent.selectedIndex != index {
                parent.selectedIndex = index
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}
 
