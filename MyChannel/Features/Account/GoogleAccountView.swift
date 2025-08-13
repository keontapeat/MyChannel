//
//  GoogleAccountView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI
import SafariServices

struct GoogleAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthenticationManager
    @State private var isLoading = false
    @State private var showSafari = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: auth.currentUser?.profileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color(.systemGray5))
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.currentUser?.displayName ?? "Not signed in")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(auth.currentUser?.email ?? "Sign in to manage your Google account")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Button {
                            showSafari = true
                        } label: {
                            Label("Manage account", systemImage: "globe")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.primary))
                        }
                        .buttonStyle(.plain)

                        if auth.isAuthenticated {
                            Button(role: .destructive) {
                                auth.signOut()
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                Task { await signInWithGoogle() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "g.circle.fill")
                                    Text(isLoading ? "Signing in..." : "Sign in with Google")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(RoundedRectangle(cornerRadius: 12).fill(.black))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.Colors.surface))
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Google Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: URL(string: "https://myaccount.google.com")!)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.Colors.primary)
            Text("Manage your Google account")
                .font(.title2.weight(.bold))
            Text("Connect, manage, or sign out of your Google account to personalize your experience.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 20)
    }

    private func signInWithGoogle() async {
        isLoading = true
        defer { isLoading = false }
        await auth.signInWithGoogle()
        if auth.isAuthenticated {
            HapticManager.shared.impact(style: .medium)
        }
    }
}

#Preview("GoogleAccountView") {
    let auth = AuthenticationManager.shared
    auth.currentUser = User.sampleUsers.first
    auth.isAuthenticated = true
    return GoogleAccountView()
        .environmentObject(auth)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}