//
//  FlicksGestureLayer.swift
//  MyChannel
//
//  UIKit tap/double-tap/long-press layer extracted from FlicksView.
//

import SwiftUI

struct UIKitFlicksGestureLayer: UIViewRepresentable {
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPressBegan: () -> Void
    var onLongPressEnded: () -> Void = {}

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false

        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTap))
        singleTap.numberOfTapsRequired = 1

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap))
        doubleTap.numberOfTapsRequired = 2

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPress(_:)))
        longPress.minimumPressDuration = 0.35

        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(longPress)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: UIKitFlicksGestureLayer

        init(parent: UIKitFlicksGestureLayer) {
            self.parent = parent
        }

        @objc func singleTap() {
            parent.onSingleTap()
        }

        @objc func doubleTap() {
            parent.onDoubleTap()
        }

        @objc func longPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                parent.onLongPressBegan()
            case .ended, .cancelled, .failed:
                parent.onLongPressEnded()
            default:
                break
            }
        }
    }
}
