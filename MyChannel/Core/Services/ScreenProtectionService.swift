import SwiftUI
import Combine

/// Detects and blocks screen recording/screenshots of premium content.
/// Uses built-in UIKit APIs — no package required.
@MainActor
final class ScreenProtectionService: ObservableObject {
    static let shared = ScreenProtectionService()

    @Published var isBeingRecorded = false
    @Published var isBeingMirrored = false
    @Published var shouldBlurContent = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        startMonitoring()
    }

    // MARK: - Monitor screen capture state

    private func startMonitoring() {
        // Check immediately
        updateCaptureState()

        // Watch for changes via NotificationCenter
        NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateCaptureState() }
            .store(in: &cancellables)
    }

    private func updateCaptureState() {
        let captured = UIScreen.main.isCaptured
        let mirrored = UIScreen.screens.count > 1

        isBeingRecorded = captured
        isBeingMirrored = mirrored
        shouldBlurContent = captured || mirrored

        if captured {
            AgentLogService.shared.agentFailed(
                "ScreenProtection", agentId: "screen",
                error: "Screen recording detected — premium content blurred"
            )
        }
    }

    // MARK: - Check before showing premium content

    func canShowPremiumContent() -> Bool {
        return !isBeingRecorded && !isBeingMirrored
    }

    // MARK: - Screenshot notification

    func startScreenshotDetection(onScreenshot: @escaping () -> Void) {
        NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in onScreenshot() }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI View Modifier

struct ScreenProtectedModifier: ViewModifier {
    @ObservedObject private var protection = ScreenProtectionService.shared
    let isPremium: Bool

    func body(content: Content) -> some View {
        if isPremium && protection.shouldBlurContent {
            ZStack {
                content.blur(radius: 40).allowsHitTesting(false)
                VStack(spacing: 12) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                    Text("Screen recording detected")
                        .font(.headline).foregroundColor(.white)
                    Text("Premium content is protected")
                        .font(.subheadline).foregroundColor(.white.opacity(0.8))
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        } else {
            content
        }
    }
}

extension View {
    func screenProtected(isPremium: Bool = true) -> some View {
        modifier(ScreenProtectedModifier(isPremium: isPremium))
    }
}
