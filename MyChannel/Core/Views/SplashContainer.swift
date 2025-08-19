//
//  SplashContainer.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SplashContainer: View {
    @State private var showSplash = true
    @State private var showLaunchMask = false

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    enum PreviewMode {
        case splashOnly
        case simpleHome
        case safeMainTab
    }

    var previewMode: PreviewMode = .splashOnly

    var body: some View {
        contentView
            .ignoresSafeArea(.keyboard)
            .onAppear {
                if isRunningInPreviews {
                    disablePreviewURLProtocolStubIfAny()
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if isRunningInPreviews {
            previewContent
        } else {
            liveContent
        }
    }

    private var previewContent: AnyView {
        switch previewMode {
        case .splashOnly:
            return AnyView(PreviewSplashStandalone())
        case .simpleHome:
            return AnyView(PreviewTransitionContainer { HomeView() })
        case .safeMainTab:
            return AnyView(PreviewTransitionContainer { MainTabView() })
        }
    }

    private var liveContent: AnyView {
        AnyView(
            ZStack {
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSplash = false
                        }
                        showLaunchMask = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showLaunchMask = false
                            }
                        }
                    }
                    .transition(AnyTransition.opacity)
                    .zIndex(1)
                } else {
                    HomeView()
                        .transition(AnyTransition.opacity)
                }
            }
            .overlay(
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(showLaunchMask ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: showLaunchMask)
            )
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if showSplash {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSplash = false
                        }
                        showLaunchMask = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showLaunchMask = false
                            }
                        }
                    }
                }
            }
        )
    }

    private func disablePreviewURLProtocolStubIfAny() {
        let names = [
            "PreviewImageURLProtocol",
            (Bundle.main.infoDictionary?["CFBundleName"] as? String).map { "\($0).PreviewImageURLProtocol" }
        ].compactMap { $0 }

        for name in names {
            if let cls = NSClassFromString(name) {
                _ = (cls as? AnyClass).map { URLProtocol.unregisterClass($0) }
            }
        }
    }
}

private struct PreviewSplashStandalone: View {
    var body: some View {
        SplashView { }
            .preferredColorScheme(.light)
    }
}

private struct PreviewTransitionContainer<Content: View>: View {
    @State private var showSplash = true
    @State private var showLaunchMask = false
    let content: () -> Content

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                    showLaunchMask = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showLaunchMask = false
                        }
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            } else {
                content()
                    .transition(.opacity)
            }
        }
        .overlay(
            Color(.systemBackground)
                .ignoresSafeArea()
                .opacity(showLaunchMask ? 1 : 0)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.25), value: showLaunchMask)
        )
        .animation(.easeInOut(duration: 0.4), value: showSplash)
    }
}

#Preview("Splash Only (Safe)") {
    SplashContainer(previewMode: .splashOnly)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}

#Preview("Splash (All Modes Safe In Preview)") {
    SplashContainer(previewMode: .safeMainTab)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}