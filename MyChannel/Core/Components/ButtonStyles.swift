//
//  ButtonStyles.swift
//  MyChannel
//
//  Shared button styles used across the app
//

import SwiftUI
import UIKit

enum iPadLayout {
    static let maxContentWidth: CGFloat = 900
    static let tabBarMaxWidth: CGFloat = 500
    static let signInSheetWidth: CGFloat = 420

    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static func videoCardWidth(in proxy: GeometryProxy) -> CGFloat {
        let available = proxy.size.width
        if available >= 1024 {
            return (available - 80) / 4
        } else if available >= 768 {
            return (available - 64) / 3
        } else if available >= 500 {
            return (available - 48) / 2.5
        } else {
            return 180
        }
    }

    static func gridColumns(for width: CGFloat, minItemWidth: CGFloat = 160) -> [GridItem] {
        let count = max(1, Int(width / minItemWidth))
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }
}

private struct AdaptiveCardWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 180
}

extension EnvironmentValues {
    var adaptiveCardWidth: CGFloat {
        get { self[AdaptiveCardWidthKey.self] }
        set { self[AdaptiveCardWidthKey.self] = newValue }
    }
}

// MARK: - iPad Readable Content Width Modifier
/// Apple's UIKit gives `readableContentGuide` automatically; SwiftUI does not.
/// Without this, SwiftUI ScrollView content extends edge-to-edge on iPad and looks
/// left-aligned/empty in the center. Apply this to inner content (lists, grids,
/// link sections) on iPad to center them at a readable max width while keeping
/// edge-to-edge banners/headers untouched.
///
/// Reference: https://swiftwithmajid.com/2024/04/23/content-margins-in-swiftui/
private struct IPadReadableWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var maxWidth: CGFloat = iPadLayout.maxContentWidth

    func body(content: Content) -> some View {
        if iPadLayout.isIPad && sizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}

extension View {
    /// Centers content at `iPadLayout.maxContentWidth` on iPad regular size class;
    /// leaves content unchanged on iPhone / compact size class.
    func iPadReadableWidth(_ maxWidth: CGFloat = iPadLayout.maxContentWidth) -> some View {
        modifier(IPadReadableWidthModifier(maxWidth: maxWidth))
    }
}

// MARK: - Scale Button Style
/// A button style that scales down slightly when pressed for a tactile feel
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.95
    var dampingFraction: CGFloat = 0.7
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: dampingFraction), value: configuration.isPressed)
    }
}

// MARK: - Bounce Button Style
/// A button style with more pronounced bounce animation
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Glow Button Style
/// A button style that adds a subtle glow when pressed
struct GlowButtonStyle: ButtonStyle {
    var glowColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: configuration.isPressed ? glowColor.opacity(0.5) : .clear, radius: 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - UIKit Sheet Presentation Modifier
/// Configures the underlying UISheetPresentationController so SwiftUI sheets
/// get native iOS detents, a proper grabber, rounded corners, and
/// scroll-expand behaviour — identical to system sheets like Apple Music / Maps.
struct UIKitSheetModifier: ViewModifier {
    /// Detents to offer. Defaults to medium + large (like UIKit default).
    var detents: [UISheetPresentationController.Detent] = [.medium(), .large()]
    /// Show the grabber pill at the top.
    var showGrabber: Bool = true
    /// Corner radius of the sheet card. nil → system default.
    var cornerRadius: CGFloat? = 20
    /// Allow the sheet to expand further when the user scrolls up inside it.
    var scrollingExpandsToLargeDetent: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                UIKitSheetConfigurator(
                    detents: detents,
                    showGrabber: showGrabber,
                    cornerRadius: cornerRadius,
                    scrollingExpandsToLargeDetent: scrollingExpandsToLargeDetent
                )
            )
    }
}

private struct UIKitSheetConfigurator: UIViewRepresentable {
    var detents: [UISheetPresentationController.Detent]
    var showGrabber: Bool
    var cornerRadius: CGFloat?
    var scrollingExpandsToLargeDetent: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard
                let viewController = uiView.parentViewController,
                let sheet = viewController.sheetPresentationController
            else { return }

            sheet.detents = detents
            sheet.prefersGrabberVisible = showGrabber
            sheet.prefersScrollingExpandsWhenScrolledToEdge = scrollingExpandsToLargeDetent
            sheet.prefersEdgeAttachedInCompactHeight = false
            if let radius = cornerRadius {
                sheet.preferredCornerRadius = radius
            }
        }
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

extension View {
    /// Apply native UIKit sheet presentation controller configuration.
    func uiKitSheet(
        detents: [UISheetPresentationController.Detent] = [.medium(), .large()],
        showGrabber: Bool = true,
        cornerRadius: CGFloat? = 20,
        scrollingExpandsToLargeDetent: Bool = true
    ) -> some View {
        modifier(UIKitSheetModifier(
            detents: detents,
            showGrabber: showGrabber,
            cornerRadius: cornerRadius,
            scrollingExpandsToLargeDetent: scrollingExpandsToLargeDetent
        ))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Button("Scale Button") {}
            .buttonStyle(ScaleButtonStyle())
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        
        Button("Bounce Button") {}
            .buttonStyle(BounceButtonStyle())
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        
        Button("Glow Button") {}
            .buttonStyle(GlowButtonStyle(glowColor: .purple))
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
    .padding()
}




