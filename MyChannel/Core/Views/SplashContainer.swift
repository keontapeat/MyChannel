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
        case splashOnly
        case simpleHome
        case safeMainTab
        case profileLiveDemo
    }

    var previewMode: PreviewMode = .splashOnly

    var body: some View {
        Group {
            if isRunningInPreviews {
                switch previewMode {
                case .splashOnly:
                    PreviewSplashStandalone()
                case .simpleHome:
                    PreviewTransitionContainer {
                        LightweightHomeStub()
                    }
                case .safeMainTab:
                    PreviewTransitionContainer {
                        LightweightMainTabPreview()
                    }
                case .profileLiveDemo:
                    PreviewTransitionContainer {
                        LightweightProfileStub()
                    }
                }
            } else {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
        .onAppear {
            if isRunningInPreviews {
                disablePreviewURLProtocolStubIfAny()
            }
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
        SplashView { }
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

// MARK: - Ultra-lightweight preview stubs (no heavy StateObjects)

private struct LightweightMainTabPreview: View {
    @State private var selected = 0
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selected {
                case 0: LightweightHomeStub()
                case 1: LightweightFlicksStub()
                case 2: LightweightUploadStub()
                case 3: LightweightSearchStub()
                default: LightweightProfileStub()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

            HStack(spacing: 32) {
                tabItem("house.fill", index: 0)
                tabItem("bolt.fill", index: 1)
                tabItem("plus.circle.fill", index: 2)
                tabItem("magnifyingglass", index: 3)
                tabItem("person.crop.circle.fill", index: 4)
            }
            .padding(.vertical, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
        }
        .preferredColorScheme(.light)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: selected)
    }

    private func tabItem(_ system: String, index: Int) -> some View {
        Button {
            selected = index
        } label: {
            Image(systemName: system)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selected == index ? Color.red : Color.secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(selected == index ? Color.red.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct LightweightHomeStub: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("MyChannel")
                        .font(.largeTitle.bold())
                    Spacer()
                    Circle().fill(Color.red.opacity(0.12))
                        .overlay(Image(systemName: "bell.badge.fill").foregroundStyle(.red))
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<8, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Color.red.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(
                                    VStack(alignment: .leading, spacing: 6) {
                                        Capsule().fill(Color.red).frame(width: 36, height: 6)
                                        Capsule().fill(Color.primary.opacity(0.2)).frame(width: 80, height: 8)
                                        Capsule().fill(Color.primary.opacity(0.15)).frame(width: 120, height: 8)
                                    }
                                    .padding(12)
                                )
                                .frame(width: 180, height: 110)
                                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(width: 120, height: 72)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Capsule().fill(Color.primary.opacity(0.2)).frame(height: 10)
                                        Capsule().fill(Color.primary.opacity(0.12)).frame(width: 160, height: 8)
                                        Capsule().fill(Color.primary.opacity(0.1)).frame(width: 120, height: 8)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                            )
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

private struct LightweightFlicksStub: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.red.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 220, height: 380)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                Text("Flicks Preview")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LightweightUploadStub: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.red)
            Text("Upload Center")
                .font(.title3.weight(.semibold))
            Text("Preview-friendly placeholder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LightweightSearchStub: View {
    @State private var text = ""
    var body: some View {
        VStack(spacing: 12) {
            TextField("Search MyChannel", text: $text)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            Spacer()
        }
    }
}

private struct LightweightProfileStub: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 140)
                    HStack(spacing: 12) {
                        Circle().fill(Color.red.opacity(0.15))
                            .overlay(Image(systemName: "person.fill").font(.system(size: 28, weight: .bold)).foregroundStyle(.red))
                            .frame(width: 72, height: 72)
                            .offset(x: 12, y: 12)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Creator Name")
                                .font(.title3.bold())
                            Text("@mychannel • 1.2M subscribers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .offset(y: 12)
                        Spacer()
                    }
                }
                .padding(.horizontal)

                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 80)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Previews

#Preview("Splash Only (Safe)") {
    SplashContainer(previewMode: .splashOnly)
        .preferredColorScheme(.light)
}

#Preview("Lightweight Main Tab (Safe)") {
    SplashContainer(previewMode: .safeMainTab)
        .preferredColorScheme(.light)
}

#Preview("Lightweight Home (Safe)") {
    SplashContainer(previewMode: .simpleHome)
        .preferredColorScheme(.light)
}