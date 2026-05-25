import SwiftUI
import UIKit

struct UIKitSearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFirstResponder: Bool = false
    var onFocusChanged: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .yes
        searchBar.returnKeyType = .search
        searchBar.searchBarStyle = .minimal
        searchBar.text = text
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
        if isFirstResponder, uiView.window != nil, !(uiView.searchTextField.isFirstResponder) {
            uiView.becomeFirstResponder()
        }
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: UIKitSearchBar

        init(_ parent: UIKitSearchBar) {
            self.parent = parent
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            if parent.text != searchText {
                parent.text = searchText
            }
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            parent.onFocusChanged?(true)
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            parent.onFocusChanged?(false)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""
            searchBar.text = ""
            searchBar.resignFirstResponder()
        }
    }
}
