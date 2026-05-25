import SwiftUI
import UIKit

struct NativeShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    var onComplete: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }

        controller.popoverPresentationController?.delegate = context.coordinator
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: \.isKeyWindow) {
            controller.popoverPresentationController?.sourceView = window
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: window.bounds.midX,
                y: window.bounds.midY,
                width: 0,
                height: 0
            )
            controller.popoverPresentationController?.permittedArrowDirections = []
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
        func adaptivePresentationStyle(for controller: UIPresentationController,
                                       traitCollection: UITraitCollection) -> UIModalPresentationStyle {
            .none
        }
    }
}
