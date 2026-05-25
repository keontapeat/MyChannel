//
//  AdvancedScrollOptimizer.swift
//  MyChannel
//
//  🎬 ADVANCED SCROLL PERFORMANCE
//  60fps scrolling with viewport rendering and intelligent prefetching
//

import SwiftUI
import Combine

// MARK: - Scroll Performance Optimizer
@MainActor
class AdvancedScrollOptimizer: ObservableObject {
    static let shared = AdvancedScrollOptimizer()
    
    @Published var currentFPS: Double = 60.0
    @Published var droppedFrames: Int = 0
    
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    private init() {
        setupFPSMonitoring()
    }
    
    // MARK: - FPS Monitoring
    
    private func setupFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFPS(displayLink: CADisplayLink) {
        if lastFrameTime == 0 {
            lastFrameTime = displayLink.timestamp
            return
        }
        
        let elapsed = displayLink.timestamp - lastFrameTime
        frameCount += 1
        
        // Update FPS every second
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            currentFPS = fps
            
            // Track dropped frames (below 60fps)
            if fps < 58.0 {
                droppedFrames += 1
                print("⚠️ [ScrollOptimizer] FPS drop detected: \(Int(fps))fps")
            }
            
            frameCount = 0
            lastFrameTime = displayLink.timestamp
        }
    }
    
    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - Viewport-Based Rendering

struct ViewportRenderer<Content: View>: View {
    let content: Content
    @State private var isInViewport = false
    @State private var hasRendered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ViewportPreferenceKey.self, value: geometry.frame(in: .global))
                .onPreferenceChange(ViewportPreferenceKey.self) { frame in
                    checkViewport(frame: frame)
                }
        }
        .overlay(
            Group {
                if isInViewport || hasRendered {
                    content
                        .onAppear {
                            hasRendered = true
                        }
                } else {
                    // Placeholder for off-screen content
                    Color.clear
                }
            }
        )
    }
    
    private func checkViewport(frame: CGRect) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let screenBounds = window.bounds
        let expandedBounds = screenBounds.insetBy(dx: 0, dy: -screenBounds.height) // 1 screen buffer
        
        isInViewport = expandedBounds.intersects(frame)
    }
}

struct ViewportPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Optimized Video Grid

struct OptimizedVideoGrid<Item: Identifiable>: View {
    let items: [Item]
    let columns: Int
    let itemContent: (Item) -> AnyView
    
    @State private var visibleRange: Range<Int> = 0..<20
    @StateObject private var scrollOptimizer = AdvancedScrollOptimizer.shared
    
    private let itemsPerRow: Int
    private let estimatedRowHeight: CGFloat = 200
    
    init(
        items: [Item],
        columns: Int = 2,
        @ViewBuilder itemContent: @escaping (Item) -> AnyView
    ) {
        self.items = items
        self.columns = columns
        self.itemsPerRow = columns
        self.itemContent = itemContent
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: []) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if shouldRender(index: index) {
                        itemContent(item)
                            .id(item.id)
                    } else {
                        // Placeholder for off-screen items
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: estimatedRowHeight)
                            .id(item.id)
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .global).minY) { _ in
                        updateVisibleRange(geometry: geometry)
                    }
            }
        )
    }
    
    private func shouldRender(index: Int) -> Bool {
        return visibleRange.contains(index)
    }
    
    private func updateVisibleRange(geometry: GeometryProxy) {
        let scrollOffset = -geometry.frame(in: .global).minY
        let viewHeight = geometry.size.height
        
        let firstVisibleRow = max(0, Int(scrollOffset / estimatedRowHeight) - 2)
        let lastVisibleRow = min(items.count / itemsPerRow, Int((scrollOffset + viewHeight) / estimatedRowHeight) + 2)
        
        let firstIndex = firstVisibleRow * itemsPerRow
        let lastIndex = min(items.count, (lastVisibleRow + 1) * itemsPerRow)
        
        visibleRange = firstIndex..<lastIndex
        
        // Prefetch images for visible range
        prefetchImagesInRange()
    }
    
    private func prefetchImagesInRange() {
        // Implement image prefetching for visible items
        // This would integrate with ImagePrefetcher
    }
}

// MARK: - Smooth Scroll View

struct SmoothScrollView<Content: View>: View {
    let content: Content
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .global).minY)
                    }
                )
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            calculateVelocity(offset: offset)
        }
    }
    
    private func calculateVelocity(offset: CGFloat) {
        let delta = offset - lastScrollOffset
        scrollVelocity = delta
        lastScrollOffset = offset
        
        // Adjust prefetching based on scroll velocity
        if abs(scrollVelocity) > 100 {
            // Fast scrolling - reduce prefetching
            ImagePrefetcher.shared.cancelAll()
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extensions

extension View {
    func viewportOptimized() -> some View {
        ViewportRenderer {
            self
        }
    }
    
    func smoothScrolling() -> some View {
        self
            .drawingGroup() // Flatten view hierarchy for better performance
    }
}

// MARK: - List Performance Helper

struct PerformantList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    @State private var visibleIndices: Set<Data.Element.ID> = []
    @StateObject private var memoryManager = DynamicMemoryManager.shared
    
    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8, pinnedViews: []) {
                ForEach(data, id: \.id) { item in
                    content(item)
                        .onAppear {
                            visibleIndices.insert(item.id)
                        }
                        .onDisappear {
                            visibleIndices.remove(item.id)
                            
                            // Clear from cache if memory pressure
                            if memoryManager.memoryPressureLevel != .normal {
                                // Implement cache cleanup for off-screen items
                            }
                        }
                }
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}
