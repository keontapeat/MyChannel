//
//  ProfileSwitcherView.swift
//  MyChannel
//
//  Switch between signed-in accounts (YouTube-style multi-account).
//

import SwiftUI

struct ProfileSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AccountSwitcherView()
            .environmentObject(authManager)
            .environmentObject(appState)
    }
}

#Preview {
    ProfileSwitcherView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager.shared)
}
