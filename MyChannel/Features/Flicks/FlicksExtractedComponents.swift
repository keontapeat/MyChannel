// ⚡ PERFORMANCE: Extracted from FlicksView.swift — independent compilation unit.
// UIKit gesture/progress layers and ViewModel compile in parallel with the main FlicksView.
import SwiftUI
import AVFoundation

// MARK: - Nuclear Flick Model



// MARK: - Nuclear Video Player View

struct UIKitFlicksProgressRail: UIViewRepresentable {
    let count: Int
    @Binding var currentIndex: Int
    let reduceMotion: Bool
    let onSelect: (Int) -> Void
    
    func makeUIView(context: Context) -> FlicksProgressRailView {
        let view = FlicksProgressRailView()
        view.onSelect = { index in
            onSelect(index)
        }
        return view
    }
    
    func updateUIView(_ uiView: FlicksProgressRailView, context: Context) {
        uiView.configure(count: count, currentIndex: currentIndex, reduceMotion: reduceMotion)
        uiView.onSelect = { index in
            onSelect(index)
        }
    }
}

final class FlicksProgressRailView: UIView {
    var onSelect: ((Int) -> Void)?
    
    private var count: Int = 0
    private var currentIndex: Int = 0
    private var reduceMotion: Bool = false
    private var segmentLayers: [CALayer] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(count: Int, currentIndex: Int, reduceMotion: Bool) {
        self.count = count
        self.currentIndex = min(max(currentIndex, 0), max(count - 1, 0))
        self.reduceMotion = reduceMotion
        rebuildLayersIfNeeded()
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard count > 0 else { return }
        let maxVisible = min(count, 18)
        let spacing: CGFloat = 6
        let segmentHeight: CGFloat = 10
        let selectedHeight: CGFloat = 22
        let totalHeight = CGFloat(maxVisible - 1) * (segmentHeight + spacing) + selectedHeight
        var y = (bounds.height - totalHeight) / 2
        let start = visibleStart(maxVisible: maxVisible)
        for visibleIndex in 0..<maxVisible {
            let index = start + visibleIndex
            let selected = index == currentIndex
            let height = selected ? selectedHeight : segmentHeight
            let width: CGFloat = selected ? 4 : 3
            let layer = segmentLayers[visibleIndex]
            let frame = CGRect(x: bounds.midX - width / 2, y: y, width: width, height: height)
            if reduceMotion {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.frame = frame
                layer.backgroundColor = UIColor.white.withAlphaComponent(selected ? 1 : 0.35).cgColor
                CATransaction.commit()
            } else {
                layer.frame = frame
                layer.backgroundColor = UIColor.white.withAlphaComponent(selected ? 1 : 0.35).cgColor
            }
            layer.cornerRadius = width / 2
            y += height + spacing
        }
    }
    
    private func rebuildLayersIfNeeded() {
        let targetCount = min(count, 18)
        guard segmentLayers.count != targetCount else { return }
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers = (0..<targetCount).map { _ in
            let layer = CALayer()
            layer.shadowColor = UIColor.white.cgColor
            layer.shadowOpacity = 0.25
            layer.shadowRadius = 4
            self.layer.addSublayer(layer)
            return layer
        }
    }
    
    private func visibleStart(maxVisible: Int) -> Int {
        guard count > maxVisible else { return 0 }
        let half = maxVisible / 2
        return min(max(currentIndex - half, 0), count - maxVisible)
    }
    
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard count > 0 else { return }
        let maxVisible = min(count, 18)
        let start = visibleStart(maxVisible: maxVisible)
        let location = recognizer.location(in: self)
        let segmentHeight = bounds.height / CGFloat(maxVisible)
        let visibleIndex = min(max(Int(location.y / max(segmentHeight, 1)), 0), maxVisible - 1)
        let index = min(start + visibleIndex, count - 1)
        onSelect?(index)
    }
}

// MARK: - Nuclear Flicks ViewModel

// MARK: - Preview
#Preview("Flicks View") {
    FlicksView()
        .preferredColorScheme(.dark)
}

