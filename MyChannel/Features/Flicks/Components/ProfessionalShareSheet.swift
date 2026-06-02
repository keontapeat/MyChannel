import SwiftUI

/// Flicks share sheet. Wraps the app's functional `EnhancedVideoShareSheet`
/// (native share, copy link, Messages, WhatsApp) and records a real share
/// event in Firestore so share counts are tracked.
struct ProfessionalShareSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss

    /// Public, shareable universal link for a flick.
    private var shareURL: String {
        "https://mychannel.live/flicks/\(video.id)"
    }

    var body: some View {
        EnhancedVideoShareSheet(video: video, shareURL: shareURL)
            .onAppear {
                recordShare()
            }
    }

    private func recordShare() {
        Task {
            try? await ShortsFirestoreService.shared.incrementShareCount(flickId: video.id)
        }
    }
}

#Preview {
    ProfessionalShareSheet(video: Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}
