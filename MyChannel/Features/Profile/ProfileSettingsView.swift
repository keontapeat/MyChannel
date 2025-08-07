//
//  ProfileSettingsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var notificationsEnabled: Bool = true
    @State private var privateProfile: Bool = false
    @State private var showAnalytics: Bool = true
    @State private var autoPlayVideos: Bool = true
    @State private var downloadQuality: DownloadQuality = .high
    @State private var showingSignOutAlert: Bool = false
    @State private var showingDeleteAccountAlert: Bool = false
    @State private var showingPremiumSheet: Bool = false
    
    // Simulate premium status - you can connect this to your user model
    @State private var isPremiumUser: Bool = false
    @State private var currentUser: User = User.sampleUsers[0]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Premium Upgrade Section (only show if not premium)
                    if !isPremiumUser {
                        premiumUpgradeSection
                    }
                    
                    // Account Settings
                    accountSettingsSection
                    
                    // Privacy Settings
                    privacySettingsSection
                    
                    // Content Settings
                    contentSettingsSection
                    
                    // Notification Settings
                    notificationSettingsSection
                    
                    // Premium Features Section (only show if premium)
                    if isPremiumUser {
                        premiumFeaturesSection
                    }
                    
                    // Danger Zone
                    dangerZoneSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .sheet(isPresented: $showingPremiumSheet) {
                PremiumUpgradeView(isPremiumUser: $isPremiumUser)
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // Handle account deletion
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
    
    // MARK: - Premium Upgrade Section
    private var premiumUpgradeSection: some View {
        VStack(spacing: 0) {
            // Premium Header
            ZStack {
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.8),
                        Color.blue.opacity(0.8),
                        Color.cyan.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    // Subtle pattern overlay
                    GeometryReader { geometry in
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            // Create subtle geometric pattern
                            for i in 0..<10 {
                                let x = CGFloat(i) * width / 10
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x + 20, y: height))
                            }
                        }
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                )
                
                VStack(spacing: 16) {
                    // MyChannel Premium Logo - Using "m" asset
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 60, height: 60)
                        
                        Image("m")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    VStack(spacing: 8) {
                        Text("MyChannel Premium")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Unlock the full experience")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.vertical, 32)
            }
            .cornerRadius(16, corners: [.topLeft, .topRight])
            
            // Premium Features List
            VStack(spacing: 0) {
                PremiumFeatureRow(
                    icon: "play.circle.fill",
                    title: "Ad-Free Experience",
                    description: "No interruptions, pure content"
                )
                
                Divider().padding(.leading, 56)
                
                PremiumFeatureRow(
                    icon: "arrow.down.circle.fill",
                    title: "Offline Downloads",
                    description: "Watch anywhere, anytime"
                )
                
                Divider().padding(.leading, 56)
                
                PremiumFeatureRow(
                    icon: "4k.tv.fill",
                    title: "4K Ultra HD",
                    description: "Crystal clear video quality"
                )
                
                Divider().padding(.leading, 56)
                
                PremiumFeatureRow(
                    icon: "music.note.list",
                    title: "Background Play",
                    description: "Keep playing when app is closed"
                )
                
                Divider().padding(.leading, 56)
                
                PremiumFeatureRow(
                    icon: "star.circle.fill",
                    title: "Exclusive Content",
                    description: "Premium-only shows and features"
                )
                
                // Upgrade Button
                Button(action: {
                    showingPremiumSheet = true
                    HapticManager.shared.impact(style: .medium)
                }) {
                    HStack(spacing: 12) {
                        Image("m")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        Text("Upgrade to Premium")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("$9.99/mo")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(AppTheme.Colors.cardBackground)
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        }
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Premium Features Section (for premium users)
    private var premiumFeaturesSection: some View {
        VStack(spacing: 0) {
            // Header with proper constraints
            HStack(spacing: 8) {
                Image("m")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                
                Text("Premium Features")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("Active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.cardBackground)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "tv.fill",
                    title: "Premium Content",
                    subtitle: "Access exclusive shows and content",
                    action: {
                        HapticManager.shared.impact(style: .light)
                    }
                )
                
                Divider()
                    .padding(.leading, 64)
                
                SettingsRow(
                    icon: "folder.fill",
                    title: "My Downloads",
                    subtitle: "Manage your offline content",
                    action: {
                        HapticManager.shared.impact(style: .light)
                    }
                )
                
                Divider()
                    .padding(.leading, 64)
                
                SettingsRow(
                    icon: "creditcard.fill",
                    title: "Manage Subscription",
                    subtitle: "View billing and payment options",
                    action: {
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
            .background(AppTheme.Colors.cardBackground)
        }
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    private var accountSettingsSection: some View {
        VStack(spacing: 0) {
            // Header with proper constraints
            HStack {
                Text("Account")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.cardBackground)
            
            VStack(spacing: 0) {
                NavigationLink {
                    EditProfileView(user: $currentUser)
                } label: {
                    SettingsRowContent(
                        icon: "person.circle",
                        title: "Edit Profile",
                        subtitle: "Update your profile information"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 64)
                
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    SettingsRowContent(
                        icon: "key",
                        title: "Change Password",
                        subtitle: "Update your account password"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 64)
                
                NavigationLink {
                    EmailSettingsView()
                } label: {
                    SettingsRowContent(
                        icon: "envelope",
                        title: "Email Settings",
                        subtitle: "Manage email preferences"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppTheme.Colors.cardBackground)
        }
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    private var privacySettingsSection: some View {
        VStack(spacing: 0) {
            // Header with proper constraints
            HStack {
                Text("Privacy")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.cardBackground)
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "lock",
                    title: "Private Profile",
                    subtitle: "Only followers can see your content",
                    isOn: $privateProfile
                )
                
                Divider()
                    .padding(.leading, 64)
                
                SettingsToggleRow(
                    icon: "chart.bar",
                    title: "Show Analytics",
                    subtitle: "Display view counts and engagement",
                    isOn: $showAnalytics
                )
                
                Divider()
                    .padding(.leading, 64)
                
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    SettingsRowContent(
                        icon: "hand.raised",
                        title: "Blocked Users",
                        subtitle: "Manage blocked accounts"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppTheme.Colors.cardBackground)
        }
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    private var contentSettingsSection: some View {
        VStack(spacing: 0) {
            // Header with proper constraints
            HStack {
                Text("Content")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.cardBackground)
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "play.circle",
                    title: "Auto-Play Videos",
                    subtitle: "Videos play automatically",
                    isOn: $autoPlayVideos
                )
                
                Divider()
                    .padding(.leading, 64)
                
                SettingsPickerRow(
                    icon: "arrow.down.circle",
                    title: "Download Quality",
                    subtitle: downloadQuality.displayName,
                    selection: $downloadQuality,
                    options: DownloadQuality.allCases
                )
                
                Divider()
                    .padding(.leading, 64)
                
                SettingsRow(
                    icon: "folder",
                    title: "Downloaded Videos",
                    subtitle: "Manage offline content",
                    action: {
                        // Handle downloaded videos
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
            .background(AppTheme.Colors.cardBackground)
        }
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    private var notificationSettingsSection: some View {
        VStack(spacing: 0) {
            // Header with proper constraints
            HStack {
                Text("Notifications")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.cardBackground)
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell",
                    title: "Push Notifications",
                    subtitle: "Receive app notifications",
                    isOn: $notificationsEnabled
                )
                
                Divider()
                    .padding(.leading, 64)
                
                NavigationLink {
                    NotificationPreferencesView()
                } label: {
                    SettingsRowContent(
                        icon: "bell.badge",
                        title: "Notification Preferences",
                        subtitle: "Choose what notifications to receive"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppTheme.Colors.cardBackground)
        }
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    private var dangerZoneSection: some View {
        VStack(spacing: 0) {
            // Header with proper constraints
            HStack {
                Text("Account Actions")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.error)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.cardBackground)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "arrow.right.square",
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    titleColor: AppTheme.Colors.error,
                    action: {
                        showingSignOutAlert = true
                        HapticManager.shared.impact(style: .medium)
                    }
                )
                
                Divider()
                    .padding(.leading, 64)
                
                SettingsRow(
                    icon: "trash",
                    title: "Delete Account",
                    subtitle: "Permanently delete your account",
                    titleColor: AppTheme.Colors.error,
                    action: {
                        showingDeleteAccountAlert = true
                        HapticManager.shared.impact(style: .heavy)
                    }
                )
            }
            .background(AppTheme.Colors.cardBackground)
        }
        .cornerRadius(16)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let titleColor: Color
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        titleColor: Color = AppTheme.Colors.textPrimary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.action = action
    }
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with proper sizing
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                // Text content with proper constraints
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron with proper sizing
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with proper sizing
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            // Text content with proper constraints
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Toggle with proper sizing
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(0.9)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct SettingsPickerRow<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selection: T
    let options: [T]
    
    @State private var showingPicker: Bool = false
    
    var body: some View {
        Button {
            showingPicker = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: 16) {
                // Icon with proper sizing
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                // Text content with proper constraints
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron with proper sizing
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog(title, isPresented: $showingPicker) {
            ForEach(options, id: \.self) { option in
                Button(option.rawValue.capitalized) {
                    selection = option
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Download Quality Enum
enum DownloadQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium" 
    case high = "high"
    case ultra = "ultra"
    
    var displayName: String {
        switch self {
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .ultra: return "Ultra (4K)"
        }
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with proper sizing and background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            // Text content with proper layout
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Check mark with proper sizing
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Premium Upgrade View
struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPremiumUser: Bool
    
    @State private var selectedPlan: PremiumPlan = .monthly
    @State private var showingPayment: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image("m")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(spacing: 8) {
                            Text("Go Premium")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Unlock the ultimate MyChannel experience")
                                .font(.title3)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Premium Benefits
                    VStack(spacing: 24) {
                        PremiumBenefitCard(
                            icon: "nosign",
                            title: "Ad-Free Videos",
                            description: "Watch your favorite content without any interruptions",
                            color: .red
                        )
                        
                        PremiumBenefitCard(
                            icon: "arrow.down.to.line.circle.fill",
                            title: "Download & Watch Offline",
                            description: "Save videos to watch later, even without internet",
                            color: .blue
                        )
                        
                        PremiumBenefitCard(
                            icon: "4k.tv.fill",
                            title: "4K Ultra HD Quality",
                            description: "Experience content in stunning 4K resolution",
                            color: .purple
                        )
                        
                        PremiumBenefitCard(
                            icon: "play.fill",
                            title: "Background Playback",
                            description: "Keep videos playing when you switch apps",
                            color: .green
                        )
                        
                        PremiumBenefitCard(
                            icon: "star.fill",
                            title: "Exclusive Premium Content",
                            description: "Access premium shows and creator exclusives",
                            color: .orange
                        )
                    }
                    
                    // Pricing Plans
                    VStack(spacing: 16) {
                        Text("Choose Your Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        VStack(spacing: 12) {
                            PremiumPlanCard(
                                plan: .monthly,
                                isSelected: selectedPlan == .monthly,
                                onSelect: { selectedPlan = .monthly }
                            )
                            
                            PremiumPlanCard(
                                plan: .yearly,
                                isSelected: selectedPlan == .yearly,
                                onSelect: { selectedPlan = .yearly }
                            )
                        }
                    }
                    
                    // Subscribe Button
                    VStack(spacing: 16) {
                        Button(action: {
                            // Simulate successful purchase
                            HapticManager.shared.impact(style: .heavy)
                            
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isPremiumUser = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image("m")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                
                                Text("Start Premium - \(selectedPlan.price)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(spacing: 8) {
                            Text("• Cancel anytime")
                            Text("• No hidden fees")
                            Text("• 7-day free trial")
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Premium Benefit Card
struct PremiumBenefitCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Text content with proper spacing
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Premium Plan Card
struct PremiumPlanCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            onSelect()
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Plan info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(plan.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            if plan == .yearly {
                                Text("SAVE 40%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.orange, Color.red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(8)
                            }
                        }
                        
                        Text(plan.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Pricing info
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(plan.price)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if plan == .yearly {
                            Text("$16.66/mo")
                                .font(.system(size: 13))
                                .strikethrough()
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // Selection indicator
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.clear)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.blue : AppTheme.Colors.textTertiary, lineWidth: 2)
                            )
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? 
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) : 
                                LinearGradient(
                                    colors: [Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ), 
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.2) : AppTheme.Colors.textPrimary.opacity(0.05),
                        radius: isSelected ? 12 : 8,
                        x: 0,
                        y: isSelected ? 6 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Premium Plan Enum
enum PremiumPlan: CaseIterable {
    case monthly
    case yearly
    
    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    var subtitle: String {
        switch self {
        case .monthly: return "Billed monthly"
        case .yearly: return "Billed annually"
        }
    }
    
    var price: String {
        switch self {
        case .monthly: return "$9.99/mo"
        case .yearly: return "$99.19/yr"
        }
    }
}

// MARK: - View Extensions
extension View {
    func AcardStyle() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadow(
                color: AppTheme.Colors.textPrimary.opacity(0.05),
                radius: 8,
                x: 0,
                y: 2
            )
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Settings Row Content (for NavigationLink consistency)
struct SettingsRowContent: View {
    let icon: String
    let title: String
    let subtitle: String
    let titleColor: Color
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        titleColor: Color = AppTheme.Colors.textPrimary
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with proper sizing
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            // Text content with proper constraints
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Chevron with proper sizing
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthenticationManager.shared)
}