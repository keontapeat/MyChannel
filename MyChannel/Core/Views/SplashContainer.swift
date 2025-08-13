//
//  SplashContainer.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

struct SplashContainer: View {
    @State private var showSplash = true

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    enum PreviewMode {
        case splashOnly       // Default: avoid crashing previews
        case simpleHome       // Transitions to a lightweight, AV-free tab preview
        case safeMainTab      // Transitions to a safer MainTab wrapper (reduced risk)
    }

    // This has no effect in the real app; previews can set a different mode in #Preview
    var previewMode: PreviewMode = .splashOnly

    var body: some View {
        Group {
            if isRunningInPreviews {
                // Preview-safe modes
                switch previewMode {
                case .splashOnly:
                    PreviewSplashStandalone()
                case .simpleHome:
                    PreviewTransitionContainer {
                        SimpleMainTabPreview()
                            .preferredColorScheme(.light)
                    }
                case .safeMainTab:
                    PreviewTransitionContainer {
                        PreviewSafeMainTabWrapper()
                            .preferredColorScheme(.light)
                    }
                }
            } else {
                // Real app runtime
                ZStack {
                    if showSplash {
                        SplashView {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                        .transition(.opacity)
                    } else {
                        MainTabView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: showSplash)
                .onAppear {
                    // Fallback: ensure we always advance in case onComplete doesn't fire
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if showSplash {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

private struct PreviewSplashStandalone: View {
    var body: some View {
        SplashView {
            // No-op in splash-only preview to avoid transitioning into heavy views
        }
        .preferredColorScheme(.light)
    }
}

private struct PreviewTransitionContainer<Content: View>: View {
    @State private var showSplash = true
    let content: () -> Content

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                content()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
    }
}

#Preview("Splash Container • App Behavior") {
    SplashContainer() // Real app logic; preview stays on splash to avoid crashes
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}

#Preview("Splash → Simple Home (Safe)") {
    SplashContainer(previewMode: .simpleHome)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}

#Preview("Splash → Safe MainTab (Safer)") {
    SplashContainer(previewMode: .safeMainTab)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}