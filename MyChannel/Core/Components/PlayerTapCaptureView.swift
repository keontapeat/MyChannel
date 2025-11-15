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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onDoubleTap: onDoubleTap)
    }
    
    func makeUIView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        view.backgroundColor = .clear
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(singleTap)
        
        context.coordinator.hostView = view
        return view
    }
    
    func updateUIView(_ uiView: PassthroughView, context: Context) {
        context.coordinator.hostView = uiView
    }
    
    final class Coordinator: NSObject {
        let onSingleTap: () -> Void
        let onDoubleTap: (_ location: CGPoint, _ size: CGSize) -> Void
        weak var hostView: UIView?
        
        init(onSingleTap: @escaping () -> Void,
             onDoubleTap: @escaping (_ location: CGPoint, _ size: CGSize) -> Void) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
        }
        
        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            onSingleTap()
        }
        
        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let hostView = hostView else { return }
            let location = recognizer.location(in: hostView)
            onDoubleTap(location, hostView.bounds.size)
        }
    }
}

/// Transparent view that lets touches pass through except when gestures handle them.
final class PassthroughView: UIView {}

