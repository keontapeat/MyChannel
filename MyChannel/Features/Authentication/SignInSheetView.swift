//
//  SignInSheetView.swift
//  MyChannel
//
//  Created by AI Assistant on 9/27/25.
//

import SwiftUI
import AuthenticationServices

struct SignInSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isLoadingGoogle: Bool = false
    @State private var isLoadingApple: Bool = false
    @State private var showFullAuth: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Header
                VStack(spacing: 12) {
                    Image("MyChannel")
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)

                    Text("Sign in to MyChannel")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Access your likes, subscriptions, watch history and more.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 4)
                .padding(.bottom, 20)

                // Buttons
                VStack(spacing: 12) {
                    // Google
                    Button(action: { Task { await googleTap() } }) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(isLoadingGoogle ? "Signing in…" : "Sign in with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingGoogle || isLoadingApple)

                    // Apple
                    Button(action: { Task { await appleTap() } }) {
                        HStack(spacing: 12) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(isLoadingApple ? "Signing in…" : "Sign in with Apple")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.label))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingGoogle || isLoadingApple)

                    // Divider
                    HStack {
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        Text("or")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // Email
                    Button {
                        showFullAuth = true
                    } label: {
                        Text("Use email instead")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                Spacer()

                // Footer
                VStack(spacing: 6) {
                    Text("By continuing, you agree to our Terms and acknowledge our Privacy Policy.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onChange(of: authManager.isAuthenticated) { isAuth in
                if isAuth { dismiss() }
            }
            .fullScreenCover(isPresented: $showFullAuth) {
                AuthenticationView()
            }
        }
    }

    // MARK: - Actions
    private func googleTap() async {
        guard !isLoadingApple else { return }
        isLoadingGoogle = true
        defer { isLoadingGoogle = false }
        do {
            try await AuthService.shared.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appleTap() async {
        guard !isLoadingGoogle else { return }
        isLoadingApple = true
        defer { isLoadingApple = false }
        // Small delay to let the sheet finish layout before presenting SIWA controller
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Use AuthenticationManager (the @EnvironmentObject source of truth)
        // so isAuthenticated updates correctly and the sheet auto-dismisses.
        // Errors/cancellation are handled internally via authState.
        await authManager.signInWithApple()
        // Show error if auth failed
        if case .error(let msg) = authManager.authState {
            errorMessage = msg
        }
    }
}

#Preview("SignInSheetView") {
    SignInSheetView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}


