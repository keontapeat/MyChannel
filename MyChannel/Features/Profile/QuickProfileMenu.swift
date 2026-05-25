//
//  QuickProfileMenu.swift
//  MyChannel
//
//  Created by AI Assistant on 11/1/25.
//

import SwiftUI

/// Clean, minimal profile menu that appears when tapping profile icon
/// Shows quick stats, settings, and sign out - NO full profile navigation
struct QuickProfileMenu: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    
    @State private var showingSignOutConfirm = false
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    
    private var user: User {
        appState.currentUser ?? authManager.currentUser ?? User.defaultUser
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with avatar and basic info
            VStack(spacing: 12) {
                ProfileAvatarView(urlString: user.profileImageURL, size: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if user.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Quick Stats Row
            HStack(spacing: 0) {
                StatColumn(value: formatCount(user.subscriberCount), label: "Subscribers")
                
                Divider()
                    .frame(height: 40)
                    .background(Color.gray.opacity(0.2))
                
                StatColumn(value: formatCount(user.videoCount), label: "Videos")
                
                Divider()
                    .frame(height: 40)
                    .background(Color.gray.opacity(0.2))
                
                StatColumn(value: formatCount(user.totalViews ?? 0), label: "Views")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // Action Buttons
            VStack(spacing: 12) {
                MenuButton(
                    icon: "person.crop.circle",
                    title: "Edit Profile",
                    action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingEditProfile = true
                        }
                    }
                )
                
                MenuButton(
                    icon: "gearshape",
                    title: "Settings",
                    action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingSettings = true
                        }
                    }
                )
                
                MenuButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    titleColor: .red,
                    action: {
                        HapticManager.shared.impact(style: .medium)
                        showingSignOutConfirm = true
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(20)
            }
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                try? authManager.signOut()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showingSettings) {
            SafeProfileSettingsView()
                .environmentObject(appState)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingEditProfile) {
            if let currentUser = appState.currentUser {
                EditProfileView(user: .constant(currentUser))
                    .environmentObject(appState)
                    .environmentObject(authManager)
            }
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Stat Column
private struct StatColumn: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Button
private struct MenuButton: View {
    let icon: String
    let title: String
    var titleColor: Color = AppTheme.Colors.textPrimary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(titleColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(titleColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickProfileMenu()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager.shared)
}

