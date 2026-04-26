import SwiftUI
import UIKit

struct UIKitSheetConfiguration {
    var detents: [UISheetPresentationController.Detent] = [.medium(), .large()]
    var largestUndimmedDetentIdentifier: UISheetPresentationController.Detent.Identifier? = nil
    var prefersGrabberVisible: Bool = true
    var prefersScrollingExpandsWhenScrolledToEdge: Bool = false
    var preferredCornerRadius: CGFloat? = 24
}

struct UIKitSheetConfigurator: UIViewControllerRepresentable {
    let configuration: UIKitSheetConfiguration

    func makeUIViewController(context: Context) -> UIViewController {
        Controller(configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let controller = uiViewController as? Controller else { return }
        controller.configuration = configuration
        controller.applyConfigurationIfPossible()
    }

    final class Controller: UIViewController {
        var configuration: UIKitSheetConfiguration

        init(configuration: UIKitSheetConfiguration) {
            self.configuration = configuration
            super.init(nibName: nil, bundle: nil)
            view = UIView(frame: .zero)
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyConfigurationIfPossible()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyConfigurationIfPossible()
        }

        func applyConfigurationIfPossible() {
            guard let sheet = parent?.presentationController as? UISheetPresentationController ?? presentationController as? UISheetPresentationController else { return }
            sheet.detents = configuration.detents
            sheet.largestUndimmedDetentIdentifier = configuration.largestUndimmedDetentIdentifier
            sheet.prefersGrabberVisible = configuration.prefersGrabberVisible
            sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollingExpandsWhenScrolledToEdge
            if let preferredCornerRadius = configuration.preferredCornerRadius {
                sheet.preferredCornerRadius = preferredCornerRadius
            }
        }
    }
}
