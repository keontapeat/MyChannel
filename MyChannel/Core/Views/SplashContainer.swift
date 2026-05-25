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
    @State private var hasAcceptedEULA = UserDefaults.standard.bool(forKey: "hasAcceptedEULA")

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
        Group {
            if isRunningInPreviews {
                switch previewMode {
                case .splashOnly:
                    PreviewSplashStandalone()
                case .simpleHome:
                    PreviewTransitionContainer { HomeView() }
                case .safeMainTab:
                    PreviewTransitionContainer { MainTabView() }
                }
            } else {
                ZStack {
                    if showSplash {
                        SplashView {
                            print("✅ [SplashView] onComplete called - transitioning to MainTabView")
                            proceedFromSplash()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("👆 [SplashView] Tapped - skipping to MainTabView")
                            proceedFromSplash()
                        }
                        .transition(.opacity)
                        .zIndex(1)
                    } else if !hasAcceptedEULA {
                        // 🔒 EULA Gate (Guideline 1.2): Must accept terms before UGC access
                        EULAAcceptanceView(hasAcceptedEULA: $hasAcceptedEULA)
                            .transition(.opacity)
                    } else {
                        // Always start unauthenticated unless user signs in (fresh TestFlight behavior)
                        MainTabView()
                            .transition(.opacity)
                            .onAppear {
                                print("🏠 [MainTabView] Appeared successfully!")
                            }
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
                    print("🎬 [SplashContainer] Started - waiting for SplashView completion")
                    // 🔥 BACKUP TIMER: Only transition if SplashView callback fails
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if showSplash {
                            print("⏰ [SplashContainer] Backup timer triggered - forcing transition")
                            proceedFromSplash()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if isRunningInPreviews {
                disablePreviewURLProtocolStubIfAny()
            }
        }
    }

    private func proceedFromSplash() {
        guard showSplash else {
            print("⚠️ [SplashContainer] proceedFromSplash called but already transitioned")
            return
        }
        
        print("🎯 [SplashContainer] proceedFromSplash - Starting transition to MainTabView")
        
        withAnimation(.easeInOut(duration: 0.4)) {
            showSplash = false
        }
        showLaunchMask = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showLaunchMask = false
            }
            print("✅ [SplashContainer] Transition complete - MainTabView should be visible")
        }
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
        // Make the "splash only" preview interactive too: tap to fade to a simple Home.
        PreviewTransitionContainer { HomeView() }
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
                SplashView { proceed() }
                    .contentShape(Rectangle())
                    .onTapGesture { proceed() }
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

    private func proceed() {
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

#Preview("Splash Only (Safe)") {
    SplashContainer(previewMode: .splashOnly)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .environmentObject(GlobalVideoPlayerManager.shared)
        .preferredColorScheme(.light)
}

#Preview("Splash (All Modes Safe In Preview)") {
    SplashContainer(previewMode: .safeMainTab)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
        .environmentObject(GlobalVideoPlayerManager.shared)
        .preferredColorScheme(.light)
}