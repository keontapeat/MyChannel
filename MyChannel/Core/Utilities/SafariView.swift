import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var entersReaderIfAvailable: Bool = false
    var barTintColor: UIColor? = nil
    var controlTintColor: UIColor? = nil
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = entersReaderIfAvailable
        let vc = SFSafariViewController(url: url, configuration: config)
        if let barTintColor { vc.preferredBarTintColor = barTintColor }
        // Default to brand control tint if none provided
        let resolvedControlTint = controlTintColor ?? UIColor(AppTheme.Colors.primary)
        vc.preferredControlTintColor = resolvedControlTint
        vc.dismissButtonStyle = .close
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview("SafariView") {
    SafariView(url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)
}