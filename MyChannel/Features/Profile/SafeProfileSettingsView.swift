//
//  SafeProfileSettingsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

// MARK: - Safe Profile Settings View
struct SafeProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SafeViewWrapper {
            ProfileSettingsView(dismiss: dismiss)
        } fallback: {
            ProfileSettingsFallbackView(dismiss: dismiss)
        }
    }
}

// MARK: - Profile Settings View
struct ProfileSettingsView: View {
    let dismiss: DismissAction
    
    @AppStorage("preferences.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("preferences.autoPlayEnabled") private var autoPlayEnabled = true
    @AppStorage("preferences.personalizedAdsEnabled") private var personalizedAdsEnabled = true
    @StateObject private var settingsService = SettingsService.shared

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { settingsService.appSettings.general.appearanceMode == .dark },
            set: { on in
                settingsService.updateAppSettings {
                    $0.general.appearanceMode = on ? .dark : .system
                    $0.general.darkMode = on
                }
            }
        )
    }
    @State private var qualityPreference = "Auto"
    @State private var showingAccountDeletion = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDataExport = false
    @State private var showingBlockedUsers = false
    @State private var analyticsEnabled: Bool = FirebaseManager.shared.isAnalyticsEnabled()
    
    private let qualityOptions = ["Auto", "720p", "1080p", "4K"]
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                accountSection
                twoFactorSection
                sessionsSection
                
                // Preferences Section
                preferencesSection
                
                // Privacy Section
                privacySection
                
                // Owner-only Featured Controls
                ownerFeaturedSection

                // About Section
                aboutSection
                
                // Danger Zone
                dangerZoneSection
            }
            .listStyle(InsetGroupedListStyle())
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await AuthenticationManager.shared.signOut()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog("Delete Account", isPresented: $showingAccountDeletion) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do {
                        try await AuthService.shared.deleteAccount()
                        NotificationManager.shared.showSuccess("Your account has been deleted.")
                    } catch {
                        NotificationManager.shared.showError("Failed to delete account: \(error.localizedDescription)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. Your account and all data will be permanently deleted.")
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .sheet(isPresented: $showingBlockedUsers) {
            BlockedUsersView()
                .environmentObject(AuthenticationManager.shared)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenLanguageSettings"))) { _ in
            UIApplication.shared.topMostController()?.present(UIHostingController(rootView: LanguageSettingsView()), animated: true)
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section("Account") {
            ProfileSettingsRow(
                icon: "person.crop.circle",
                title: "Edit Profile",
                iconColor: AppTheme.Colors.primary
            ) {
                // Handle edit profile
            }
            
            ProfileSettingsRow(
                icon: "bell",
                title: "Notification Preferences",
                iconColor: .orange
            ) {
                NotificationCenter.default.post(name: NSNotification.Name("OpenNotificationSettings"), object: nil)
            }
            
            ProfileSettingsRow(
                icon: "shield.lefthalf.fill",
                title: "Privacy Settings",
                iconColor: .green
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }

            // Easier Sign Out (YouTube-style placement near account controls)
            ProfileSettingsRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Sign Out",
                iconColor: .orange
            ) {
                showingSignOutConfirmation = true
            }
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section("Preferences") {
            HStack {
                SettingsIcon(systemName: "play.circle", color: AppTheme.Colors.secondary)
                
                Text("Auto-play Videos")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $autoPlayEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            
            HStack {
                SettingsIcon(systemName: "bell.badge", color: .orange)
                
                Text("Push Notifications")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $notificationsEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            
            HStack {
                SettingsIcon(systemName: "chart.bar.fill", color: .green)
                
                Text("Share Analytics")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $analyticsEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            .onChange(of: analyticsEnabled) { newValue in
                FirebaseManager.shared.setAnalyticsEnabled(newValue)
            }

            // MARK: Appearance — YouTube-style inline picker
            NavigationLink(destination: ProfileAppearanceView()) {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "moon.circle.fill", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(settingsService.appSettings.general.appearanceMode.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            
            HStack {
                SettingsIcon(systemName: "video", color: .purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video Quality")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Default playback quality")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Menu(qualityPreference) {
                    ForEach(qualityOptions, id: \.self) { option in
                        Button(option) {
                            qualityPreference = option
                        }
                    }
                }
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)

            HStack {
                SettingsIcon(systemName: "hand.raised", color: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personalized Ads")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Improve relevance using topics/tags")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $personalizedAdsEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Two-Factor Authentication
    @State private var showing2FASetup = false
    @State private var twoFACode: String = ""
    private var twoFactorSection: some View {
        Section("Security") {
            HStack {
                SettingsIcon(systemName: "lock.shield", color: .blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Two‑Factor Authentication")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(AuthService.shared.twoFactorEnabled ? "Enabled" : "Disabled")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(AuthService.shared.twoFactorEnabled ? "Disable" : "Enable") {
                    Task { @MainActor in
                        if AuthService.shared.twoFactorEnabled {
                            try? await AuthService.shared.disableTwoFactor()
                        } else {
                            showing2FASetup = true
                        }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .sheet(isPresented: $showing2FASetup) {
            TwoFASetupSheet()
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
    }

    private var sessionsSection: some View {
        Section("Devices") {
            ProfileSettingsRow(
                icon: "iphone.and.arrow.forward",
                title: "Sign out of other devices",
                iconColor: .red
            ) {
                Task { await AuthService.shared.revokeOtherSessions() }
            }
            NavigationLink(destination: SessionsListView()) {
                HStack {
                    SettingsIcon(systemName: "lanyardcard", color: .gray)
                    Text("Manage devices")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Owner Featured Section (visible only for owner)
    private var ownerFeaturedSection: some View {
        Section {
            if isOwner {
                // 🔥 THERMONUCLEAR Featured Manager
                NavigationLink(destination: ThermonuclearFeaturedManager()) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Featured Videos")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            Text("Easy add/remove • Max 3 videos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink(destination: OwnerVerificationDashboardView()) {
                    HStack {
                        SettingsIcon(systemName: "checkmark.seal", color: AppTheme.Colors.verificationBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verification Dashboard")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("Approve blue checks for top creators")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Legacy Manager (hidden unless needed)
                NavigationLink(destination: OwnerFeaturedManagerView()) {
                    HStack {
                        SettingsIcon(systemName: "folder.fill", color: .gray)
                        Text("Legacy Featured Manager")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Spacer()
                    }
                }
            }
        } header: {
            if isOwner { Text("Owner Tools") }
        } footer: {
            if isOwner {
                Text("Manage which videos appear in the featured carousel on your Home feed")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var isOwner: Bool {
        (AuthenticationManager.shared.currentUser?.email ?? "").lowercased() == "keontapeat@mychannel.live"
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        Section("Privacy & Safety") {
            ProfileSettingsRow(
                icon: "hand.raised.fill",
                title: "Blocked Users",
                iconColor: .red
            ) {
                showingBlockedUsers = true
            }
            
            ProfileSettingsRow(
                icon: "eye.slash",
                title: "Watch History",
                iconColor: .gray
            ) {
                // Handle watch history
            }
            
            ProfileSettingsRow(
                icon: "location.slash",
                title: "Location Services",
                iconColor: .blue
            ) {
                // Handle location services
            }

            // Permissions Shortcuts
            ProfileSettingsRow(
                icon: "bell.badge.fill",
                title: "Notification Settings",
                iconColor: .orange
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            ProfileSettingsRow(
                icon: "camera.fill",
                title: "Camera & Microphone",
                iconColor: .indigo
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            ProfileSettingsRow(
                icon: "photo.fill.on.rectangle.fill",
                title: "Photos Access",
                iconColor: .purple
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section("About") {
            ProfileSettingsRow(
                icon: "questionmark.circle",
                title: "Help & Support",
                iconColor: .cyan
            ) {
                if let url = URL(string: "https://mychannel.live/help") {
                    UIApplication.shared.open(url)
                }
            }
            
            ProfileSettingsRow(
                icon: "envelope.fill",
                title: "Send Feedback",
                iconColor: .blue
            ) {
                let email = AppConfig.Social.supportEmail
                let subject = "App Feedback"
                let message = "Describe your issue or idea here..."
                let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let bodyEncoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let mailto = "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
                if let url = URL(string: mailto) {
                    UIApplication.shared.open(url)
                }
            }
            
            ProfileSettingsRow(
                icon: "doc.text",
                title: "Terms of Service",
                iconColor: .brown
            ) {
                if let url = URL(string: "https://mychannel.live/terms") {
                    UIApplication.shared.open(url)
                }
            }
            
            ProfileSettingsRow(
                icon: "lock.doc",
                title: "Privacy Policy",
                iconColor: .mint
            ) {
                if let url = URL(string: "https://mychannel.live/privacy") {
                    UIApplication.shared.open(url)
                }
            }

            ProfileSettingsRow(
                icon: "square.and.arrow.up",
                title: "Export My Data",
                iconColor: .teal
            ) {
                showingDataExport = true
            }

            ProfileSettingsRow(
                icon: "star.circle.fill",
                title: "Rate MyChannel",
                iconColor: .yellow
            ) {
                #if canImport(StoreKit)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
                #endif
            }

            ProfileSettingsRow(
                icon: "globe",
                title: "Language",
                iconColor: .purple
            ) {
                NotificationCenter.default.post(name: NSNotification.Name("OpenLanguageSettings"), object: nil)
            }

            ProfileSettingsRow(
                icon: "link",
                title: "Validate Universal Links",
                iconColor: .gray
            ) {
                UIApplication.shared.topMostController()?.present(UIHostingController(rootView: UniversalLinkValidatorView()), animated: true)
            }
            
            HStack {
                SettingsIcon(systemName: "info.circle", color: .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Danger Zone Section
    private var dangerZoneSection: some View {
        Section {
            Button(action: {
                showingAccountDeletion = true
            }) {
                HStack {
                    SettingsIcon(systemName: "trash", color: .red)
                    
                    Text("Delete Account")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Profile Appearance View (YouTube-style full screen)
struct ProfileAppearanceView: View {
    @StateObject private var settingsService = SettingsService.shared

    private func modeIcon(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "iphone"
        case .light:  return "sun.max"
        case .dark:   return "moon.fill"
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    miniPreview(dark: false, label: "Light",
                                selected: settingsService.appSettings.general.appearanceMode == .light)
                        .frame(maxWidth: .infinity)
                    Divider().frame(height: 120)
                    miniPreview(dark: true, label: "Dark",
                                selected: settingsService.appSettings.general.appearanceMode == .dark)
                        .frame(maxWidth: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        HapticManager.shared.impact(style: .light)
                        settingsService.updateAppSettings {
                            $0.general.appearanceMode = mode
                            $0.general.darkMode = (mode == .dark)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: modeIcon(mode))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(
                                    settingsService.appSettings.general.appearanceMode == mode
                                        ? AppTheme.Colors.primary : .secondary
                                )
                                .frame(width: 24)
                            Text(mode.displayName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Spacer()
                            if settingsService.appSettings.general.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("\"Use device theme\" automatically matches your iOS system appearance setting.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func miniPreview(dark: Bool, label: String, selected: Bool) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(dark ? Color(hexString: "0A0A0C") : Color(hexString: "FAFBFC"))
                .frame(height: 80)
                .overlay(
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(dark ? Color(hexString: "1C1C1E") : Color.white)
                            .frame(width: 60, height: 10)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(dark ? Color(hexString: "2C2C2E") : Color(hexString: "EBEDF0"))
                            .frame(width: 80, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(dark ? Color(hexString: "2C2C2E") : Color(hexString: "EBEDF0"))
                            .frame(width: 70, height: 8)
                    }
                )
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(6)
                    }
                }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(dark ? Color(hexString: "161618") : Color(hexString: "F4F5F7"))
    }
}

// MARK: - 2FA Setup Sheet
private struct TwoFASetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isLoading: Bool = false
    @State private var error: String = ""
    @State private var delivery: AuthService.TwoFactorDelivery = .email
    var body: some View {
        VStack(spacing: 14) {
            Text("Enable Two‑Factor Authentication")
                .font(.headline)
            Picker("Delivery", selection: $delivery) {
                Text("Email").tag(AuthService.TwoFactorDelivery.email)
                Text("SMS").tag(AuthService.TwoFactorDelivery.sms)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            HStack {
                TextField("Enter 6‑digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button(isLoading ? "..." : "Verify") {
                    Task { await verify() }
                }
                .disabled(code.count < 4 || isLoading)
            }
            .padding(.horizontal)
            if !error.isEmpty { Text(error).foregroundColor(.red).font(.footnote) }
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .onAppear { Task { try? await AuthService.shared.enableTwoFactor(delivery: delivery) } }
    }
    private func verify() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.shared.verifyTwoFactorCode(code: code)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Sessions List
private struct SessionsListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = true
    @State private var sessions: [DeviceSession] = []
    var body: some View {
        List {
            ForEach(sessions) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.deviceName).font(.system(size: 16, weight: .semibold))
                        Text("Last active: \(DateFormatter.localizedString(from: s.lastActive, dateStyle: .short, timeStyle: .short))")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        if let ip = s.ipAddress {
                            Text(ip).font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if s.isCurrent {
                        Text("This device").font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
                    } else {
                        Button("Sign out") { Task { await AuthService.shared.revokeSession(s.id); await load() } }
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
        }
        .navigationTitle("Your devices")
        .task { await load() }
        .refreshable { await load() }
    }
    private func load() async {
        await AuthService.shared.fetchSessions()
        sessions = AuthService.shared.sessions
        isLoading = false
    }
}
// MARK: - Settings Row
struct ProfileSettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                SettingsIcon(systemName: icon, color: iconColor)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Icon
struct SettingsIcon: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Profile Settings Fallback View
struct ProfileSettingsFallbackView: View {
    let dismiss: DismissAction
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                VStack(spacing: 8) {
                    Text("Settings Unavailable")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Unable to load settings")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(ProfileRetryButtonStyle())
            }
            .padding(40)
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
    }
}

#Preview {
    SafeProfileSettingsView()
}