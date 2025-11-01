import SwiftUI
import AVKit

struct AdPlayerOverlay: View {
    let adUrl: String
    let onFinish: () -> Void
    @State private var adPlayer = AVPlayer()
    @State private var isReady = false
    @State private var impressionId: String?

    var body: some View {
        ZStack {
            VideoPlayer(player: adPlayer)
                .background(ViewabilityTrackingView { view in
                    // Start OMID tracking when view appears
                    if impressionId == nil {
                        impressionId = OMIDViewabilityService.shared.startImpression(adId: adUrl, adView: view)
                    }
                })
                .onAppear { play() }

            if !isReady {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Text("Ad").font(.caption).foregroundColor(.white)
                        .padding(6).background(Color.black.opacity(0.6)).clipShape(Capsule())
                    Spacer()
                }
                .padding(8)
                Spacer()
            }
        }
        .background(Color.black)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            if let id = impressionId {
                let _ = OMIDViewabilityService.shared.endImpression(impressionId: id)
            }
            onFinish()
        }
        .onDisappear {
            if let id = impressionId {
                let _ = OMIDViewabilityService.shared.endImpression(impressionId: id)
            }
        }
    }

    private func play() {
        guard let url = URL(string: adUrl) else { onFinish(); return }
        let item = AVPlayerItem(url: url)
        adPlayer.replaceCurrentItem(with: item)
        adPlayer.play()
        isReady = true
    }
}

struct ViewabilityTrackingView: UIViewRepresentable {
    let onViewReady: (UIView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            onViewReady(view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}


