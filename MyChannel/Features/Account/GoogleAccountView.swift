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
            ScrollView {
                VStack(spacing: 20) {
                    // Account card
                    VStack(spacing: 0) {
                        // Avatar + name row
                        HStack(spacing: 16) {
                            AsyncImage(url: URL(string: auth.currentUser?.profileImageURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ZStack {
                                    Circle().fill(Color(.systemGray5))
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(.systemGray3))
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color(.systemGray4), lineWidth: 0.5))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(auth.currentUser?.displayName ?? "Not signed in")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                Text(auth.currentUser?.email ?? "No account connected")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Action buttons
                        if auth.isAuthenticated {
                            HStack(spacing: 10) {
                                Button {
                                    showSafari = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.circle")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("Manage account")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    try? auth.signOut()
                                    HapticManager.shared.impact(style: .light)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("Sign out")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)
                        } else {
                            Button {
                                Task { await signInWithGoogle() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.system(size: 18))
                                    Text(isLoading ? "Signing in..." : "Sign in with Google")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color(red: 0.18, green: 0.18, blue: 0.18), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                            .padding(16)
                        }
                    }
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    // Info rows card
                    VStack(spacing: 0) {
                        infoRow(
                            icon: "shield.checkered",
                            iconColor: .blue,
                            title: "Privacy & Security",
                            subtitle: "Manage your data and permissions"
                        ) { showSafari = true }

                        Divider().padding(.leading, 60)

                        infoRow(
                            icon: "bell.badge",
                            iconColor: AppTheme.Colors.primary,
                            title: "Notifications",
                            subtitle: "Manage notification preferences"
                        ) { showSafari = true }

                        Divider().padding(.leading, 60)

                        infoRow(
                            icon: "key.fill",
                            iconColor: .orange,
                            title: "Account security",
                            subtitle: "2-Step Verification and more"
                        ) { showSafari = true }
                    }
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    Spacer(minLength: 32)
                }
                .padding(.top, 20)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Google Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: URL(string: "https://myaccount.google.com")!)
            }
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
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
    let _ = {
        auth.currentUser = User.sampleUsers.first
        auth.isAuthenticated = true
    }()
    GoogleAccountView()
        .environmentObject(auth)
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}