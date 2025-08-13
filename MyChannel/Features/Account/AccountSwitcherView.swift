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
            List {
                Section {
                    ForEach(users) { user in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color(.systemGray5))
                            }
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(user.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    if user.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                }
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }

                            Spacer()

                            if user.id == auth.currentUser?.id {
                                Text("Current")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                            } else {
                                Button {
                                    switchTo(user)
                                } label: {
                                    Text("Switch")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(AppTheme.Colors.primary))
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessing)
                            }
                        }
                        .listRowBackground(AppTheme.Colors.background)
                    }
                }

                Section {
                    Button {
                        Task { await createNewAccount() }
                    } label: {
                        Label("Add another account", systemImage: "person.badge.plus")
                    }
                    .disabled(isProcessing)

                    if auth.isAuthenticated {
                        Button(role: .destructive) {
                            auth.signOut()
                            appState.clearUser()
                            dismiss()
                        } label: {
                            Label("Sign out of current account", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .listRowBackground(AppTheme.Colors.background)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Switch account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
        }
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
    auth.currentUser = User.sampleUsers.first
    auth.isAuthenticated = true
    let state = AppState()
    state.currentUser = auth.currentUser
    return AccountSwitcherView()
        .environmentObject(auth)
        .environmentObject(state)
        .preferredColorScheme(.light)
}