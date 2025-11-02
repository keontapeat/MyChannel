//
//  ProfileSwitcherView.swift
//  MyChannel
//
//  Switch between profiles and manage accounts
//

import SwiftUI

struct ProfileSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Profile
                if let currentUser = appState.currentUser {
                    VStack(spacing: 20) {
                        Text("Current Profile")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                        
                        ProfileCard(user: currentUser, isCurrent: true)
                            .padding(.horizontal, 20)
                        
                        Divider()
                            .padding(.vertical, 20)
                        
                        // Add Another Profile
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            try? authManager.signOut()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .font(.title3)
                                Text("Add Another Profile")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        Text("Sign out of your current profile to add or switch to another")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Info text
                VStack(spacing: 8) {
                    Text("Multiple Profiles Coming Soon")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Text("We're working on multi-profile support so you can easily switch between accounts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}

// MARK: - Profile Card
private struct ProfileCard: View {
    let user: User
    var isCurrent: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ProfileAvatarView(urlString: user.profileImageURL, size: 56)
                .overlay(
                    Circle()
                        .stroke(isCurrent ? AppTheme.Colors.primary : Color.clear, lineWidth: 3)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if isCurrent {
                    Text("Active")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.primary.opacity(0.15))
                        .cornerRadius(6)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatCount(user.subscriberCount))")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.primary)
                Text("subscribers")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

#Preview {
    ProfileSwitcherView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager.shared)
}

