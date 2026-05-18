#if canImport(AlertToast)
import AlertToast
#endif
import SwiftUI

/// YouTube-Style Toast Notification Service
/// Shows non-blocking confirmation toasts: "Subscribed ✓", "Saved to Playlist", etc.
@MainActor
final class ToastService: ObservableObject {
    static let shared = ToastService()

    @Published var isShowing: Bool = false
    @Published var currentToast: ToastItem = .empty

    struct ToastItem {
        let type: ToastType
        let title: String
        let subTitle: String?

        static let empty = ToastItem(type: .success, title: "", subTitle: nil)

        enum ToastType { case success, error, info, warning, loading }
    }

    private init() {}

    func show(_ title: String, subTitle: String? = nil, type: ToastItem.ToastType = .success) {
        currentToast = ToastItem(type: type, title: title, subTitle: subTitle)
        withAnimation { isShowing = true }
    }

    func showSuccess(_ title: String, subTitle: String? = nil) {
        show(title, subTitle: subTitle, type: .success)
    }

    func showError(_ title: String, subTitle: String? = nil) {
        show(title, subTitle: subTitle, type: .error)
    }

    func showLoading(_ title: String) {
        show(title, subTitle: nil, type: .loading)
    }

    func dismiss() {
        withAnimation { isShowing = false }
    }
}

// MARK: - SwiftUI View Modifier

#if canImport(AlertToast)
struct ToastModifier: ViewModifier {
    @ObservedObject var toast = ToastService.shared

    func body(content: Content) -> some View {
        content
            .toast(isPresenting: $toast.isShowing, duration: 2.5, tapToDismiss: true) {
                let t = toast.currentToast
                switch t.type {
                case .success:
                    return AlertToast(displayMode: .hud, type: .complete(.green), title: t.title, subTitle: t.subTitle)
                case .error:
                    return AlertToast(displayMode: .hud, type: .error(.red), title: t.title, subTitle: t.subTitle)
                case .warning:
                    return AlertToast(displayMode: .hud, type: .systemImage("exclamationmark.triangle", .orange), title: t.title, subTitle: t.subTitle)
                case .loading:
                    return AlertToast(displayMode: .alert, type: .loading, title: t.title)
                case .info:
                    return AlertToast(displayMode: .hud, type: .systemImage("info.circle", .blue), title: t.title, subTitle: t.subTitle)
                }
            }
    }
}

extension View {
    func withToasts() -> some View {
        modifier(ToastModifier())
    }
}
#else
extension View {
    func withToasts() -> some View { self }
}
#endif
