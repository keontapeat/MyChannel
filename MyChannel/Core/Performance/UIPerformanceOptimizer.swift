//
//  UIPerformanceOptimizer.swift
//  MyChannel
//
//  SwiftUI and UI performance optimization
//

import SwiftUI
import UIKit
import Combine

// MARK: - UI Performance Optimizer
class UIPerformanceOptimizer: ObservableObject {
    static let shared = UIPerformanceOptimizer()
    
    @Published var renderingMetrics = RenderingMetrics()
    @Published var isLowPowerModeEnabled = false
    
    private var scrollViewOptimizers: [String: ScrollViewOptimizer] = [:]
    private let animationManager = AnimationManager()
    
    private init() {
        setupPerformanceMonitoring()
        optimizeGlobalUI()
    }
    
    // MARK: - Global UI Optimization
    private func optimizeGlobalUI() {
        // Reduce motion if enabled
        if UIAccessibility.isReduceMotionEnabled {
            enableReducedMotionMode()
        }
        
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                self?.enableLowPowerUIMode()
            } else {
                self?.disableLowPowerUIMode()
            }
        }
    }
    
    private func enableReducedMotionMode() {
        UIView.setAnimationsEnabled(false)
        animationManager.disableComplexAnimations()
    }
    
    private func enableLowPowerUIMode() {
        // Reduce animation quality
        animationManager.setLowPowerMode(true)
        
        // Note: maximumFramesPerSecond is read-only, handled by system
        
        // Disable live previews
        NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
    }
    
    private func disableLowPowerUIMode() {
        animationManager.setLowPowerMode(false)
        // Note: maximumFramesPerSecond is read-only, handled by system
        NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
    }
    
    // MARK: - Performance Monitoring
    private func setupPerformanceMonitoring() {
        // Monitor view hierarchy depth
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.analyzeViewHierarchy()
        }
    }
    
    private func analyzeViewHierarchy() {
        // Use scene-based window access for iOS 15+
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let depth = calculateViewDepth(view: window)
        
        DispatchQueue.main.async {
            self.renderingMetrics.viewHierarchyDepth = depth
            
            if depth > 20 {
                print("⚠️ Deep view hierarchy detected: \(depth) levels")
            }
        }
    }
    
    private func calculateViewDepth(view: UIView) -> Int {
        var maxDepth = 0
        
        for subview in view.subviews {
            let depth = 1 + calculateViewDepth(view: subview)
            maxDepth = max(maxDepth, depth)
        }
        
        return maxDepth
    }
    
    // MARK: - Scroll View Optimization
    func optimizeScrollView(id: String, itemCount: Int) -> ScrollViewOptimizer {
        if let existing = scrollViewOptimizers[id] {
            return existing
        }
        
        let optimizer = ScrollViewOptimizer(itemCount: itemCount)
        scrollViewOptimizers[id] = optimizer
        return optimizer
    }
    
    func removeScrollViewOptimizer(id: String) {
        scrollViewOptimizers.removeValue(forKey: id)
    }
}

// MARK: - Scroll View Optimizer
class ScrollViewOptimizer: ObservableObject {
    @Published var visibleRange: Range<Int> = 0..<0
    @Published var isScrolling = false
    
    private let itemCount: Int
    private let bufferSize: Int
    private var scrollOffset: CGFloat = 0
    
    init(itemCount: Int, bufferSize: Int = 5) {
        self.itemCount = itemCount
        self.bufferSize = bufferSize
    }
    
    func updateVisibleRange(scrollOffset: CGFloat, viewHeight: CGFloat, itemHeight: CGFloat) {
        self.scrollOffset = scrollOffset
        
        let firstVisibleIndex = max(0, Int(scrollOffset / itemHeight) - bufferSize)
        let lastVisibleIndex = min(itemCount - 1, Int((scrollOffset + viewHeight) / itemHeight) + bufferSize)
        
        let newRange = firstVisibleIndex..<(lastVisibleIndex + 1)
        
        if newRange != visibleRange {
            visibleRange = newRange
        }
    }
    
    func shouldRenderItem(at index: Int) -> Bool {
        return visibleRange.contains(index)
    }
}

// MARK: - Animation Manager
class AnimationManager {
    private var isLowPowerMode = false
    private var complexAnimationsEnabled = true
    
    func setLowPowerMode(_ enabled: Bool) {
        isLowPowerMode = enabled
    }
    
    func disableComplexAnimations() {
        complexAnimationsEnabled = false
    }
    
    func optimizedAnimation<V: Equatable>(
        _ value: V,
        duration: Double = 0.3
    ) -> Animation? {
        if isLowPowerMode || !complexAnimationsEnabled {
            return nil
        }
        
        return .easeInOut(duration: duration)
    }
    
    func springAnimation() -> Animation? {
        if isLowPowerMode {
            return .linear(duration: 0.2)
        }
        
        return .spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - Rendering Metrics
struct RenderingMetrics {
    var viewHierarchyDepth: Int = 0
    var averageRenderTime: TimeInterval = 0
    var droppedFrames: Int = 0
    var memoryUsage: Double = 0
}

// MARK: - Performance-Optimized Views

// Lazy Loading Container
struct LazyContainer<Content: View>: View {
    let content: () -> Content
    @State private var isVisible = false
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if isVisible {
                content()
            } else {
                Color.clear
                    .onAppear {
                        // Delay loading to improve initial render
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isVisible = true
                        }
                    }
            }
        }
    }
}

// Optimized List View
struct OptimizedList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    @StateObject private var optimizer = UIPerformanceOptimizer.shared
    @State private var scrollViewId = UUID().uuidString
    
    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    if shouldRenderItem(at: index) {
                        content(item)
                            .id(item.id)
                    } else {
                        // Placeholder for non-visible items
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: estimatedItemHeight)
                    }
                }
            }
        }
        .onAppear {
            let _ = optimizer.optimizeScrollView(id: scrollViewId, itemCount: data.count)
        }
        .onDisappear {
            optimizer.removeScrollViewOptimizer(id: scrollViewId)
        }
    }
    
    private func shouldRenderItem(at index: Int) -> Bool {
        let scrollOptimizer = optimizer.optimizeScrollView(id: scrollViewId, itemCount: data.count)
        return scrollOptimizer.shouldRenderItem(at: index)
    }
    
    private var estimatedItemHeight: CGFloat {
        return 60 // Adjust based on your content
    }
}

// Optimized Grid View
struct OptimizedGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let columns: [GridItem]
    let content: (Data.Element) -> Content
    
    @State private var visibleItems: Set<Data.Element.ID> = []
    
    init(
        _ data: Data,
        columns: [GridItem],
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.columns = columns
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(data, id: \.id) { item in
                    content(item)
                        .onAppear {
                            visibleItems.insert(item.id)
                        }
                        .onDisappear {
                            visibleItems.remove(item.id)
                        }
                }
            }
        }
    }
}

// MARK: - Performance View Modifiers

struct PerformanceOptimizedModifier: ViewModifier {
    @StateObject private var optimizer = UIPerformanceOptimizer.shared
    
    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: false, colorMode: .nonLinear) // Flatten complex views
            .clipped() // Prevent overdraw
            .animation(
                optimizer.isLowPowerModeEnabled ? nil : .easeInOut(duration: 0.3),
                value: optimizer.isLowPowerModeEnabled
            )
    }
}

struct LazyRenderModifier: ViewModifier {
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        Group {
            if isVisible {
                content
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isVisible = true
                        }
                    }
            }
        }
    }
}

struct MemoryEfficientModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                // Handle memory warning
                ImageCache.shared.clearOldEntries()
            }
    }
}

// MARK: - View Extensions
extension View {
    func optimizeUIPerformance() -> some View {
        modifier(PerformanceOptimizedModifier())
    }
    
    func lazyRender() -> some View {
        modifier(LazyRenderModifier())
    }
    
    func memoryEfficient() -> some View {
        modifier(MemoryEfficientModifier())
    }
    
    func optimizedAnimation<V: Equatable>(
        _ value: V,
        duration: Double = 0.3
    ) -> some View {
        let animationManager = AnimationManager()
        return self.animation(animationManager.optimizedAnimation(value, duration: duration), value: value)
    }
    
    // Viewport-based rendering
    func renderInViewport() -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        // Track when view enters viewport
                    }
                    .onDisappear {
                        // Track when view leaves viewport
                    }
            }
        )
    }
}

// MARK: - Viewport Tracker
struct ViewportTracker: ViewModifier {
    let onEnterViewport: () -> Void
    let onExitViewport: () -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            onEnterViewport()
                        }
                        .onDisappear {
                            onExitViewport()
                        }
                }
            )
    }
}

extension View {
    func trackViewport(
        onEnter: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) -> some View {
        modifier(ViewportTracker(onEnterViewport: onEnter, onExitViewport: onExit))
    }
}
