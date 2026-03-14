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
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 34, height: 34)
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: 8, y: -8)
                                .opacity(1)
                        }
                    }
                    .buttonStyle(.plain)

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

#Preview {
    MinimalNavigationHeader(
        scrollOffset: 0,
        onSearchTap: {},
        onProfileTap: {}
    )
    .environmentObject(AppState())
}






