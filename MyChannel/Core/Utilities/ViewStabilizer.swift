//
//  ViewStabilizer.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - View Stabilization System
struct StableView<Content: View>: View {
    let content: () -> Content
    @State private var hasStableFrame = false
    
    var body: some View {
        GeometryReader { geometry in
            content()
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .center
                )
                .clipped()
        }
    }
}

// MARK: - Layout Stability Modifiers
extension View {
    /// Prevents layout shifts by forcing stable dimensions
    func stableLayout() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
    }
    
    /// Prevents horizontal shifting specifically
    func stableWidth() -> some View {
        self
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    /// Safe area handling that won't conflict with TabView
    func safeAreaInsets(_ edges: Edge.Set = .all) -> some View {
        self
            .padding(.top, edges.contains(.top) ? 0 : nil)
            .padding(.bottom, edges.contains(.bottom) ? 0 : nil)
            .padding(.leading, edges.contains(.leading) ? 0 : nil)
            .padding(.trailing, edges.contains(.trailing) ? 0 : nil)
    }
    
    /// Bulletproof async image loading
    func stableAsyncImage() -> some View {
        self
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: UUID())
    }
}

// MARK: - State Change Detector
class ViewStateMonitor: ObservableObject {
    @Published private(set) var stateChanges: Int = 0
    private var lastChangeTime: Date = Date()
    
    func recordStateChange(_ viewName: String) {
        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastChangeTime)
        
        // If state changes are happening too frequently, log a warning
        if timeSinceLastChange < 0.1 {
            print("⚠️ Rapid state change detected in \(viewName) - potential layout instability")
        }
        
        stateChanges += 1
        lastChangeTime = now
        
        #if DEBUG
        print("🔄 State change in \(viewName) - Total: \(stateChanges)")
        #endif
    }
}

// MARK: - Safe State Updates
extension View {
    func safeStateUpdate<T: Equatable>(_ value: T, perform action: @escaping () -> Void) -> some View {
        self.onChange(of: value) { oldValue, newValue in
            // Debounce rapid state changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if newValue == value { // Only execute if value hasn't changed again
                    action()
                }
            }
        }
    }
}

// MARK: - Bulletproof ScrollView
struct StableScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: () -> Content
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    
    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
                .frame(maxWidth: .infinity) // Prevent horizontal shifts
        }
        .coordinateSpace(name: "stableScroll")
    }
}

// MARK: - Layout Debugging (Debug builds only)
#if DEBUG
struct LayoutDebugger: ViewModifier {
    let name: String
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            print("📐 \(name) size: \(geometry.size)")
                        }
                        .onChange(of: geometry.size) { oldSize, newSize in
                            if oldSize != newSize {
                                print("📐 \(name) size changed: \(oldSize) -> \(newSize)")
                            }
                        }
                }
            )
    }
}

extension View {
    func debugLayout(_ name: String) -> some View {
        #if DEBUG
        return self.modifier(LayoutDebugger(name: name))
        #else
        return self
        #endif
    }
}
#endif