import SwiftUI
import UIKit

struct UIKitVideoScrubber: UIViewRepresentable {
    @Binding var value: Double
    let tintColor: UIColor
    let minimumTrackColor: UIColor
    let maximumTrackColor: UIColor
    let onEditingChanged: (Bool) -> Void
    let onScrubChanged: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = Float(value)
        slider.minimumTrackTintColor = minimumTrackColor
        slider.maximumTrackTintColor = maximumTrackColor
        slider.tintColor = tintColor
        slider.isContinuous = true
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: [.touchDown])
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }

    func updateUIView(_ uiView: UISlider, context: Context) {
        context.coordinator.parent = self
        let newValue = Float(value)
        if abs(uiView.value - newValue) > 0.0001 {
            uiView.value = newValue
        }
        uiView.minimumTrackTintColor = minimumTrackColor
        uiView.maximumTrackTintColor = maximumTrackColor
        uiView.tintColor = tintColor
    }

    final class Coordinator: NSObject {
        var parent: UIKitVideoScrubber

        init(_ parent: UIKitVideoScrubber) {
            self.parent = parent
        }

        @objc func touchDown(_ sender: UISlider) {
            parent.onEditingChanged(true)
        }

        @objc func valueChanged(_ sender: UISlider) {
            let newValue = Double(sender.value)
            if parent.value != newValue {
                parent.value = newValue
            }
            parent.onScrubChanged(newValue)
        }

        @objc func touchEnded(_ sender: UISlider) {
            let newValue = Double(sender.value)
            if parent.value != newValue {
                parent.value = newValue
            }
            parent.onScrubChanged(newValue)
            parent.onEditingChanged(false)
        }
    }
}
