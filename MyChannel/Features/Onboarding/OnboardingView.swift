//
//  OnboardingView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/12/25.
//

import SwiftUI

// MARK: - OnboardingView
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    @State private var page: Int = 0
    @State private var isAnimating: Bool = false
    @State private var allowNotifications: Bool = true
    @State private var allowPersonalization: Bool = true

    private let pages: [OnboardingPage] = OnboardingPage.sample

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .black, Color(.sRGB, red: 0.04, green: 0.04, blue: 0.06, opacity: 1)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                pager
                footer
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { isAnimating = true }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill").foregroundStyle(AppTheme.Colors.primary)
                Text("MyChannel")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            Spacer()
            Button("Skip") { complete() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.1))
    }

    // MARK: - Pager
    private var pager: some View {
        TabView(selection: $page) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                OnboardingCard(page: page)
                    .tag(index)
                    .padding(.horizontal, 24)
            }
            // Permissions lightweight screen
            VStack(spacing: 16) {
                Text("Make it yours")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Allow personalized recommendations", isOn: $allowPersonalization)
                    .tint(AppTheme.Colors.primary)
                Toggle("Enable notifications", isOn: $allowNotifications)
                    .tint(AppTheme.Colors.primary)
                Spacer()
                primaryButton(title: "Continue") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        self.page = pages.count + 1
                    }
                }
            }
            .padding(24)
            .tag(pages.count)

            // Final create profile
            VStack(spacing: 16) {
                Text("Ready to create?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("You can customize later in Settings.")
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                primaryButton(title: "Get Started") { complete() }
            }
            .padding(24)
            .tag(pages.count + 1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.45, dampingFraction: 0.9), value: page)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { progressBar }
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            ForEach(0..<(pages.count + 2), id: \.self) { i in
                Capsule()
                    .fill(i == page ? AppTheme.Colors.primary : .white.opacity(0.15))
                    .frame(width: i == page ? 22 : 6, height: 6)
            }
            Spacer()
            Button(action: { withAnimation { page = min(page + 1, pages.count + 1) } }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial.opacity(0.05))
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.white.opacity(0.15))
                .frame(height: 3)
                .overlay(
                    Capsule()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: proxy.size.width * CGFloat(Double(page + 1) / Double(pages.count + 2)), height: 3),
                    alignment: .leading
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(height: 3)
        .allowsHitTesting(false)
    }

    private func complete() {
        didCompleteOnboarding = true
        dismiss()
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Components
private struct OnboardingCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 320)
                    .overlay(
                        Image(systemName: page.systemImage)
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(page.subtitle)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Model
struct OnboardingPage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let gradient: [Color]

    static let sample: [OnboardingPage] = [
        .init(title: "Discover creators", subtitle: "Follow pros, artists, and communities you love.", systemImage: "person.2.fill", gradient: [AppTheme.Colors.primary.opacity(0.9), .blue.opacity(0.7)]),
        .init(title: "Watch your way", subtitle: "Shorts, long-form, live—seamless and smooth.", systemImage: "play.rectangle.fill", gradient: [.purple.opacity(0.9), .pink.opacity(0.7)]),
        .init(title: "Create in seconds", subtitle: "Upload, trim, and share with powerful tools.", systemImage: "plus.circle.fill", gradient: [.orange.opacity(0.9), .red.opacity(0.7)])
    ]
}

#Preview("Onboarding") {
    OnboardingView()
        .preferredColorScheme(.dark)
}


