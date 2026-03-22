//
//  EULAAcceptanceView.swift
//  MyChannel
//
//  EULA/Terms acceptance gate (App Store Guideline 1.2 - UGC Safety)
//  Users must accept terms before accessing user-generated content.
//

import SwiftUI

struct EULAAcceptanceView: View {
    @Binding var hasAcceptedEULA: Bool
    @State private var showFullTerms = false
    @State private var showFullPrivacy = false
    @State private var scrolledToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("MyChannel")
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Terms & Conditions")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)

                Text("Please review and accept our terms before continuing.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)

            // Scrollable terms summary
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    eulaSection(
                        icon: "doc.text",
                        title: "End-User License Agreement",
                        body: "By using MyChannel you agree to our Terms of Service and Privacy Policy. MyChannel is a user-generated content platform — you are responsible for content you create and share."
                    )

                    eulaSection(
                        icon: "shield.checkered",
                        title: "Zero-Tolerance Content Policy",
                        body: "MyChannel has a ZERO-TOLERANCE policy for objectionable content and abusive users. Content depicting violence, hate speech, nudity, exploitation, harassment, or illegal activity is strictly prohibited and will be removed immediately."
                    )

                    eulaSection(
                        icon: "flag",
                        title: "Reporting & Moderation",
                        body: "You can report objectionable content or abusive users using the flag/report option on any video, comment, or profile. You can also block users to immediately remove their content from your feed. Our moderation team reviews all reports within 24 hours."
                    )

                    eulaSection(
                        icon: "person.crop.circle.badge.xmark",
                        title: "Account Enforcement",
                        body: "Users who violate our content policy will have their content removed and their accounts suspended or permanently banned. Repeated violations result in permanent removal from the platform."
                    )

                    eulaSection(
                        icon: "lock.shield",
                        title: "Your Privacy",
                        body: "We respect your privacy and protect your personal data. We do not sell your information. Review our Privacy Policy for full details on how we handle your data."
                    )

                    // Links to full documents
                    VStack(spacing: 12) {
                        Button(action: { showFullTerms = true }) {
                            HStack {
                                Image(systemName: "doc.plaintext")
                                Text("Read Full Terms of Service")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(AppTheme.Colors.primary.opacity(0.08))
                            .cornerRadius(10)
                        }

                        Button(action: { showFullPrivacy = true }) {
                            HStack {
                                Image(systemName: "hand.raised")
                                Text("Read Full Privacy Policy")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(AppTheme.Colors.primary.opacity(0.08))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            // Accept button
            VStack(spacing: 12) {
                Divider()

                Button(action: acceptTerms) {
                    Text("Agree & Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                Text("By tapping \"Agree & Continue\" you accept our Terms of Service and Privacy Policy.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
            .padding(.bottom, 16)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showFullTerms) {
            NavigationStack {
                TermsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showFullTerms = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showFullPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showFullPrivacy = false }
                        }
                    }
            }
        }
    }

    private func acceptTerms() {
        UserDefaults.standard.set(true, forKey: "hasAcceptedEULA")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "eulaAcceptedAt")
        withAnimation(.easeInOut(duration: 0.3)) {
            hasAcceptedEULA = true
        }
        HapticManager.shared.notification(type: .success)
    }

    @ViewBuilder
    private func eulaSection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(body)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    EULAAcceptanceView(hasAcceptedEULA: .constant(false))
}
