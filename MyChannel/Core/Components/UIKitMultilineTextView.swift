import SwiftUI
import UIKit

struct UIKitMultilineTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont = .systemFont(ofSize: 16)
    var textColor: UIColor = .label
    var placeholderColor: UIColor = .placeholderText
    var isFirstResponder: Bool = false
    var maxLength: Int? = nil
    var onFocusChanged: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.font = font
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.tag = Coordinator.placeholderTag
        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 4),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -4),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8)
        ])

        textView.text = text
        context.coordinator.updatePlaceholderVisibility(in: textView)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font
        uiView.textColor = textColor
        if let placeholderLabel = uiView.viewWithTag(Coordinator.placeholderTag) as? UILabel {
            placeholderLabel.text = placeholder
            placeholderLabel.font = font
            placeholderLabel.textColor = placeholderColor
        }
        context.coordinator.parent = self
        context.coordinator.updatePlaceholderVisibility(in: uiView)

        if isFirstResponder, uiView.window != nil, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        static let placeholderTag = 9_001
        var parent: UIKitMultilineTextView

        init(_ parent: UIKitMultilineTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChanged?(true)
            updatePlaceholderVisibility(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChanged?(false)
            updatePlaceholderVisibility(in: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            var updatedText = textView.text ?? ""
            if let maxLength = parent.maxLength, updatedText.count > maxLength {
                updatedText = String(updatedText.prefix(maxLength))
                textView.text = updatedText
            }
            if parent.text != updatedText {
                parent.text = updatedText
            }
            updatePlaceholderVisibility(in: textView)
        }

        func updatePlaceholderVisibility(in textView: UITextView) {
            guard let placeholderLabel = textView.viewWithTag(Self.placeholderTag) as? UILabel else { return }
            placeholderLabel.isHidden = !(textView.text ?? "").isEmpty
        }
    }
}
