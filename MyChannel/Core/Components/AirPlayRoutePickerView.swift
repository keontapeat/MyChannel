import SwiftUI
import AVKit

// Simple wrapper for AVRoutePickerView (AirPlay)
struct AirPlayRoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.activeTintColor = UIColor(AppTheme.Colors.primary)
        v.tintColor = UIColor(AppTheme.Colors.textSecondary)
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}


