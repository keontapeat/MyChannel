//
//  MinimalNavigationHeader.swift
//  MyChannel
//
//  Extracted from HomeView.swift for better code organization
//

import SwiftUI

// MARK: - Minimal Navigation Header
struct MinimalNavigationHeader: View {
    let scrollOffset: CGFloat
    let onSearchTap: () -> Void
    let onProfileTap: () -> Void

    @EnvironmentObject private var appState: AppState
    @StateObject private var notifStore = NotificationsStore.shared

    private var logoSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 28 : 32
    }

    var body: some View {
        let showBackground = scrollOffset > 50
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Image("MyChannel")
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)

                    Text("MyChannel")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        onSearchTap()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 34, height: 34)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: NotificationsView()) {
                        NotificationsBellButton(unreadCount: notifStore.unreadCount)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.shared.impact(style: .light)
                    })

                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        onProfileTap()
                    }) {
                        ProfileAvatarView(urlString: appState.currentUser?.profileImageURL, size: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 12)
            .background(Color.white)
            .animation(.easeInOut(duration: 0.25), value: showBackground)
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Notifications Bell Button
struct NotificationsBellButton: View {
    let unreadCount: Int
    @State private var bellAngle: Double = 0
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.0
    @State private var badgeScale: CGFloat = 0.0

    var body: some View {
        ZStack {
            // Pulse ring behind badge for new notifications
            Circle()
                .fill(Color.red.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
                .offset(x: 9, y: -9)

            // Background circle
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 34, height: 34)

            // Bell icon with shake
            Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(unreadCount > 0 ? .primary : .primary)
                .rotationEffect(.degrees(bellAngle))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.primary, Color.red)

            // Badge count
            if unreadCount > 0 {
                ZStack {
                    Capsule()
                        .fill(Color.red)
                        .frame(
                            width: unreadCount > 9 ? 20 : 16,
                            height: 16
                        )
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(badgeScale)
                .offset(x: unreadCount > 9 ? 11 : 9, y: -11)
            }
        }
        .frame(width: 34, height: 34)
        .onChange(of: unreadCount) { newVal in
            guard newVal > 0 else { return }
            shakeBell()
            pulseBadge()
            pulseRing()
        }
        .onAppear {
            if unreadCount > 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    badgeScale = 1.0
                }
                shakeBell()
                pulseRing()
            }
        }
    }

    private func shakeBell() {
        let shakeSeq: [Double] = [-8, 8, -6, 6, -4, 4, -2, 2, 0]
        var delay = 0.0
        for angle in shakeSeq {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.07)) {
                    bellAngle = angle
                }
            }
            delay += 0.07
        }
    }

    private func pulseBadge() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            badgeScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                badgeScale = 1.0
            }
        }
    }

    private func pulseRing() {
        ringScale = 1.0
        ringOpacity = 0.8
        withAnimation(.easeOut(duration: 0.9)) {
            ringScale = 2.8
            ringOpacity = 0.0
        }
    }
}

#Preview {
    MinimalNavigationHeader(
        scrollOffset: 0,
        onSearchTap: {},
        onProfileTap: {}
    )
    .environmentObject(AppState())
}






