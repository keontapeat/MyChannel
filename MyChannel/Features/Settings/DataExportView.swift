import SwiftUI
import UIKit

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Export your basic profile and app usage data as JSON.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Button(action: exportData) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export JSON")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(AppTheme.Colors.primary, in: Capsule())
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func exportData() {
        let sample: [String: Any] = [
            "user": [
                "id": AppState.shared.currentUser?.id ?? "guest",
                "name": AppState.shared.currentUser?.displayName ?? "Guest"
            ],
            "watchHistoryCount": AppState.shared.watchHistory.count,
            "likedVideosCount": AppState.shared.likedVideos.count
        ]
        if let data = try? JSONSerialization.data(withJSONObject: sample, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            let av = UIActivityViewController(activityItems: [json], applicationActivities: nil)
            UIApplication.shared.presentShareSheet(av)
        }
    }
}

extension UIApplication {
    func topMostController(base: UIViewController? = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topMostController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topMostController(base: presented) }
        return base
    }

    /// Presents a UIActivityViewController in an iPad-safe way by anchoring
    /// the popover to the center of the key window so it never fails silently on iPad.
    func presentShareSheet(_ activityVC: UIActivityViewController) {
        guard let topVC = topMostController() else { return }
        // iPad requires a popover source; anchor to the center of the view.
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

#Preview {
    DataExportView()
}
