//
//  ProfileQuickMenu.swift
//  MyChannel
//
//  Created by AI Assistant on 11/1/25.
//

import SwiftUI

// MARK: - Profile Quick Menu (Dropdown from Home)
struct ProfileQuickMenu: View {
    let user: User
    @Binding var isPresented: Bool
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Avatar & Name
            VStack(spacing: 12) {
                ProfileAvatarView(urlString: user.profileImageURL, size: 64)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Stats Row
            HStack(spacing: 0) {
                StatColumn(value: formatCount(user.subscriberCount), label: "Subscribers")
                
                Divider()
                    .frame(height: 40)
                
                StatColumn(value: formatCount(user.videoCount), label: "Videos")
                
                Divider()
                    .frame(height: 40)
                
                StatColumn(value: formatCount(user.totalViews ?? 0), label: "Views")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            // Action Buttons
            VStack(spacing: 0) {
                MenuButton(
                    icon: "person.circle.fill",
                    title: "View Channel",
                    action: {
                        isPresented = false
                        // Navigate to full profile
                        NotificationCenter.default.post(
                            name: Notification.Name("OpenFullProfile"),
                            object: user
                        )
                    }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                MenuButton(
                    icon: "gearshape.fill",
                    title: "Settings",
                    action: {
                        isPresented = false
                        NotificationCenter.default.post(
                            name: Notification.Name("OpenSettings"),
                            object: nil
                        )
                    }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                MenuButton(
                    icon: "arrow.right.square.fill",
                    title: "Sign Out",
                    isDestructive: true,
                    action: {
                        HapticManager.shared.impact(style: .medium)
                        authManager.signOut()
                        isPresented = false
                    }
                )
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Button
private struct MenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : AppTheme.Colors.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
                
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileQuickMenu(
        user: User.sampleUsers[0],
        isPresented: .constant(true)
    )
    .environmentObject(AuthenticationManager.shared)
}

