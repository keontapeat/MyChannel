import SwiftUI
import AVKit

/// 🔥 Phase 13: Core Media Ecosystem
/// A SwiftUI wrapper around AVRoutePickerView for seamless AirPlay 2 integration.
struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.activeTintColor = .systemBlue
        routePickerView.tintColor = .white
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No updates needed
    }
}
