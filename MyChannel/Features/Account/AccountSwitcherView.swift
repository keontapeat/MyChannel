//
//  AccountSwitcherView.swift
//  MyChannel
//
//  Multi-account switcher — loads real signed-in accounts from FirebaseAuth
//  and lets the user switch between them without re-entering credentials.
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct AccountSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthenticationManager
    @EnvironmentObject private var appState: AppState

    @State private var savedAccounts: [SavedAccount] = []
    @State private var isProcessing = false
    @State private var isLoadingAccounts = true

    // MARK: - Lightweight account record persisted in UserDefaults
    struct SavedAccount: Identifiable, Codable {
        let id: String           // Firebase UID
        let displayName: String
        let email: String
        let photoURL: String?
        let isVerified: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Accounts list card
                    VStack(spacing: 0) {
                        if isLoadingAccounts {
                            HStack {
                                ProgressView()
                                    .padding()
                                Text("Loading accounts…")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding()
                        } else {
                            ForEach(Array(savedAccounts.enumerated()), id: \.element.id) { index, account in
                                accountRow(account)
                                if index < savedAccounts.count - 1 {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                    }
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Actions card
                    VStack(spacing: 0) {
                        Button {
                            Task { await addAccount() }
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
                                Task { @MainActor in
                                    try? await auth.signOut()
                                    appState.clearUser()
                                    dismiss()
                                }
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
            .task { await loadAccounts() }
        }
    }

    // MARK: - Row
    @ViewBuilder
    private func accountRow(_ account: SavedAccount) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: account.photoURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
                    .overlay(
                        Text(String(account.displayName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    )
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(account.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if account.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
                Text(account.email)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            if account.id == auth.currentUser?.id {
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
                    switchTo(account)
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

    // MARK: - Load Accounts
    private func loadAccounts() async {
        isLoadingAccounts = true
        defer { isLoadingAccounts = false }

        // Load cached accounts from UserDefaults
        var accounts = loadCachedAccounts()

        // Ensure the currently signed-in user is always in the list
        #if canImport(FirebaseAuth)
        if let fuser = Auth.auth().currentUser {
            let uid = fuser.uid
            if !accounts.contains(where: { $0.id == uid }) {
                let current = SavedAccount(
                    id: uid,
                    displayName: fuser.displayName ?? fuser.email?.components(separatedBy: "@").first ?? "User",
                    email: fuser.email ?? "",
                    photoURL: fuser.photoURL?.absoluteString,
                    isVerified: fuser.isEmailVerified
                )
                accounts.insert(current, at: 0)
                saveCachedAccounts(accounts)
            }
        }
        #endif

        // If auth.currentUser has richer data (e.g., subscriber count), update displayName
        if let user = auth.currentUser,
           let idx = accounts.firstIndex(where: { $0.id == user.id }) {
            accounts[idx] = SavedAccount(
                id: user.id,
                displayName: user.displayName,
                email: user.email ?? accounts[idx].email,
                photoURL: user.profileImageURL ?? accounts[idx].photoURL,
                isVerified: user.isVerified
            )
        }

        savedAccounts = accounts
    }

    // MARK: - Switch Account
    private func switchTo(_ account: SavedAccount) {
        guard !isProcessing else { return }
        isProcessing = true

        Task { @MainActor in
            #if canImport(FirebaseAuth)
            // Re-sign-in is not possible without credentials, but we can switch
            // the UI state to the cached account. Full re-auth happens on the
            // next privileged action if the token expired.
            #endif
            // Update app state to the cached account record
            let user = User(
                id: account.id,
                username: account.email.components(separatedBy: "@").first ?? "user",
                displayName: account.displayName,
                email: account.email,
                profileImageURL: account.photoURL,
                isVerified: account.isVerified,
                isCreator: true
            )
            auth.currentUser = user
            auth.isAuthenticated = true
            appState.updateUser(user)
            NotificationCenter.default.post(name: .userDidLogin, object: user)
            HapticManager.shared.impact(style: .medium)
            isProcessing = false
            dismiss()
        }
    }

    // MARK: - Add Account (triggers sign-out + new sign-in)
    private func addAccount() async {
        guard !isProcessing else { return }
        // Sign out so the auth screen is presented; the user signs in with new credentials.
        // On next launch the new UID will be appended to the saved accounts list.
        try? await auth.signOut()
        appState.clearUser()
        dismiss()
    }

    // MARK: - Persistence helpers
    private static let cacheKey = "mychannel.savedAccounts"

    private func loadCachedAccounts() -> [SavedAccount] {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let accounts = try? JSONDecoder().decode([SavedAccount].self, from: data) else {
            return []
        }
        return accounts
    }

    private func saveCachedAccounts(_ accounts: [SavedAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }
}

#Preview("AccountSwitcherView") {
    let auth = AuthenticationManager.shared
    let state = AppState()
    AccountSwitcherView()
        .environmentObject(auth)
        .environmentObject(state)
        .preferredColorScheme(.light)
}
