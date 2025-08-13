import SwiftUI

// Wrapper that bridges to the existing ModernCameraView from Stories
// and returns a captured video URL to the Upload flow.
struct ProfessionalCameraView: View {
    let onCapture: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModernCameraView { media in
            // Only pass back video captures; dismiss otherwise
            if media.type == .video {
                onCapture(media.url)
            }
            dismiss()
        }
        .ignoresSafeArea()
    }
}

#Preview("ProfessionalCameraView") {
    ProfessionalCameraView { _ in }
}