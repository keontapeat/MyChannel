//
//  PlayerTapCaptureView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/15/25.
//

import SwiftUI

struct PlayerTapCaptureView: UIViewRepresentable {
    typealias UIViewType = PassthroughView
    
    var onSingleTap: () -> Void
    var onDoubleTap: (_ location: CGPoint, _ size: CGSize) -> Void
    var onLongPressStateChanged: (_ isActive: Bool) -> Void = { _ in }
    var onPanChanged: (_ startLocation: CGPoint, _ translation: CGPoint, _ location: CGPoint, _ size: CGSize) -> Void = { _, _, _, _ in }
    var onPanEnded: (_ startLocation: CGPoint, _ translation: CGPoint, _ location: CGPoint, _ size: CGSize) -> Void = { _, _, _, _ in }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSingleTap: onSingleTap,
            onDoubleTap: onDoubleTap,
            onLongPressStateChanged: onLongPressStateChanged,
            onPanChanged: onPanChanged,
            onPanEnded: onPanEnded
        )
    }
    
    func makeUIView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        view.backgroundColor = .clear
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(singleTap)
        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(pan)
        
        context.coordinator.hostView = view
        return view
    }
    
    func updateUIView(_ uiView: PassthroughView, context: Context) {
        context.coordinator.hostView = uiView
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onSingleTap: () -> Void
        let onDoubleTap: (_ location: CGPoint, _ size: CGSize) -> Void
        let onLongPressStateChanged: (_ isActive: Bool) -> Void
        let onPanChanged: (_ startLocation: CGPoint, _ translation: CGPoint, _ location: CGPoint, _ size: CGSize) -> Void
        let onPanEnded: (_ startLocation: CGPoint, _ translation: CGPoint, _ location: CGPoint, _ size: CGSize) -> Void
        weak var hostView: UIView?
        
        init(onSingleTap: @escaping () -> Void,
             onDoubleTap: @escaping (_ location: CGPoint, _ size: CGSize) -> Void,
             onLongPressStateChanged: @escaping (_ isActive: Bool) -> Void,
             onPanChanged: @escaping (_ startLocation: CGPoint, _ translation: CGPoint, _ location: CGPoint, _ size: CGSize) -> Void,
             onPanEnded: @escaping (_ startLocation: CGPoint, _ translation: CGPoint, _ location: CGPoint, _ size: CGSize) -> Void) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
            self.onLongPressStateChanged = onLongPressStateChanged
            self.onPanChanged = onPanChanged
            self.onPanEnded = onPanEnded
        }
        
        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            onSingleTap()
        }
        
        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let hostView = hostView else { return }
            let location = recognizer.location(in: hostView)
            onDoubleTap(location, hostView.bounds.size)
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                onLongPressStateChanged(true)
            case .ended, .cancelled, .failed:
                onLongPressStateChanged(false)
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let hostView = hostView else { return }
            let startLocation = recognizer.location(in: hostView)
            let translation = recognizer.translation(in: hostView)
            let currentLocation = CGPoint(x: startLocation.x + translation.x, y: startLocation.y + translation.y)
            let size = hostView.bounds.size

            switch recognizer.state {
            case .changed:
                onPanChanged(startLocation, translation, currentLocation, size)
            case .ended, .cancelled, .failed:
                onPanEnded(startLocation, translation, currentLocation, size)
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// Transparent view that lets touches pass through except when gestures handle them.
final class PassthroughView: UIView {}

