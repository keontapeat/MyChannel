//
//  AccountSwitcherView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI

struct AccountSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthenticationManager
    @EnvironmentObject private var appState: AppState

    @State private var users: [User] = User.sampleUsers
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Accounts list card
                    VStack(spacing: 0) {
                        ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                            accountRow(user)
                            if index < users.count - 1 {
                                Divider()
                                    .padding(.leading, 70)
                            }
                        }
                    }
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Actions card
                    VStack(spacing: 0) {
                        Button {
                            Task { await createNewAccount() }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                                Text("Add another account")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing)

                        if auth.isAuthenticated {
                            Divider()
                                .padding(.leading, 68)

                            Button {
                                try? auth.signOut()
                                appState.clearUser()
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.1))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                    Text("Sign out of current account")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Switch account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func accountRow(_ user: User) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(user.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            if user.id == auth.currentUser?.id {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))
                    Text("Active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.1), in: Capsule())
            } else {
                Button {
                    switchTo(user)
                } label: {
                    Text("Switch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func switchTo(_ user: User) {
        guard !isProcessing else { return }
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            auth.currentUser = user
            auth.isAuthenticated = true
            appState.updateUser(user)
            NotificationCenter.default.post(name: .userDidLogin, object: user)
            HapticManager.shared.impact(style: .medium)
            isProcessing = false
            dismiss()
        }
    }

    private func createNewAccount() async {
        guard !isProcessing else { return }
        isProcessing = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        let new = User(
            username: "creator\(Int.random(in: 100...999))",
            displayName: "New Creator",
            email: "new@mychannel.com",
            profileImageURL: "https://picsum.photos/200/200?random=\(Int.random(in: 1...1000))",
            bio: "Just joined MyChannel 🎬",
            subscriberCount: 0,
            videoCount: 0,
            isVerified: false,
            isCreator: true
        )
        users.insert(new, at: 0)
        isProcessing = false
    }
}

#Preview("AccountSwitcherView") {
    let auth = AuthenticationManager.shared
    let state = AppState()
    let _ = {
        auth.currentUser = User.sampleUsers.first
        auth.isAuthenticated = true
        state.currentUser = auth.currentUser
    }()
    AccountSwitcherView()
        .environmentObject(auth)
        .environmentObject(state)
        .preferredColorScheme(.light)
}