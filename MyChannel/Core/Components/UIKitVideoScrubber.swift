import SwiftUI
import UIKit

struct UIKitVideoScrubber: UIViewRepresentable {
    @Binding var value: Double
    let tintColor: UIColor
    let minimumTrackColor: UIColor
    let maximumTrackColor: UIColor
    let onEditingChanged: (Bool) -> Void
    let onScrubChanged: (Double) -> Void
    /// VoiceOver announces this as "Video progress, adjustable, <accessibilityValueText>".
    /// Pass a formatted "current time of total time" string (e.g. "1:24 of 10:05")
    /// rather than letting VoiceOver read the raw 0–1 fraction, which is meaningless
    /// for a scrubber. Defaults to a generic label if the caller doesn't supply one.
    var accessibilityValueText: String? = nil

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
        slider.accessibilityLabel = "Video progress"
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
        uiView.accessibilityValue = accessibilityValueText
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
