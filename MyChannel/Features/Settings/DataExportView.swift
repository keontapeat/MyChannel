import SwiftUI
import UIKit

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
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
            UIApplication.shared.topMostController()?.present(av, animated: true)
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
}

#Preview {
    DataExportView()
}
