// ⚡ PERFORMANCE: Extracted from SettingsView.swift — independent compilation unit.
// All individual settings screen structs compile in parallel with the 540-line main SettingsView.
import SwiftUI

// MARK: - Individual Settings Views

struct GeneralSettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            Section {
                Picker(
                    "Language",
                    selection: Binding(
                        get: { settingsService.appSettings.general.language },
                        set: { value in
                            settingsService.updateAppSettings { $0.general.language = value }
                        }
                    )
                ) {
                    Text("English").tag("English")
                    Text("Español").tag("Spanish")
                    Text("Français").tag("French")
                }
                
                Picker(
                    "Country",
                    selection: Binding(
                        get: { settingsService.appSettings.general.country },
                        set: { value in
                            settingsService.updateAppSettings { $0.general.country = value }
                        }
                    )
                ) {
                    Text("United States").tag("United States")
                    Text("Canada").tag("Canada")
                    Text("United Kingdom").tag("United Kingdom")
                }
            }
            
            // MARK: Appearance — YouTube-style 3-option picker
            Section {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    AppearanceModeRow(
                        mode: mode,
                        isSelected: settingsService.appSettings.general.appearanceMode == mode,
                        onSelect: {
                            HapticManager.shared.impact(style: .light)
                            settingsService.updateAppSettings {
                                $0.general.appearanceMode = mode
                                $0.general.darkMode = (mode == .dark)
                            }
                        }
                    )
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Choose how MyChannel looks. \"Use device theme\" follows your iOS system setting.")
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance Mode Row (YouTube-style checkmark selection)
struct AppearanceModeRow: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let onSelect: () -> Void

    private var icon: String {
        switch mode {
        case .system: return "iphone"
        case .light:  return "sun.max"
        case .dark:   return "moon.fill"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : .secondary)
                    .frame(width: 24)

                Text(mode.displayName)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appearance Settings View (YouTube-style dedicated screen)
struct AppearanceSettingsView: View {
    @StateObject private var settingsService = SettingsService.shared

    var body: some View {
        List {
            // Visual preview card
            Section {
                AppearancePreviewCard(
                    mode: settingsService.appSettings.general.appearanceMode
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    AppearanceModeRow(
                        mode: mode,
                        isSelected: settingsService.appSettings.general.appearanceMode == mode,
                        onSelect: {
                            HapticManager.shared.impact(style: .light)
                            settingsService.updateAppSettings {
                                $0.general.appearanceMode = mode
                                $0.general.darkMode = (mode == .dark)
                            }
                        }
                    )
                }
            } footer: {
                Text("\"Use device theme\" automatically matches your iOS system appearance setting.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance Preview Card
struct AppearancePreviewCard: View {
    let mode: AppearanceMode

    private var isDark: Bool {
        switch mode {
        case .dark:   return true
        case .light:  return false
        case .system: return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Light preview
            appearanceSample(dark: false, label: "Light")
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    if mode == .light {
                        selectedBadge
                    }
                }

            Divider().frame(height: 120)

            // Dark preview
            appearanceSample(dark: true, label: "Dark")
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    if mode == .dark {
                        selectedBadge
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }

    private var selectedBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(AppTheme.Colors.primary)
            .padding(8)
    }

    private func appearanceSample(dark: Bool, label: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(dark ? Color(hexString: "0A0A0C") : Color(hexString: "FAFBFC"))
                .frame(height: 80)
                .overlay(
                    VStack(spacing: 4) {
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

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(dark ? Color(hexString: "161618") : Color(hexString: "F4F5F7"))
    }
}

struct SwitchAccountView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddAccount = false
    
    var body: some View {
        List {
            Section {
                if let user = AuthenticationManager.shared.currentUser {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(user.displayName.prefix(1))
                                    .font(.system(size: 20, weight: .bold))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(user.email)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            } header: {
                Text("Current account")
            }
            
            Section {
                Button {
                    showingAddAccount = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add account")
                    }
                }
            }
        }
        .navigationTitle("Switch account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// NotificationSettingsView is defined in Features/Notifications/NotificationSettingsView.swift

struct PurchasesView: View {
    @StateObject private var storeKit = StoreKitService.shared
    
    var body: some View {
        List {
            if !AppConfig.Features.enableSubscriptions {
                // 🔥 FIX 2.1(b): Hide subscription products when IAPs not submitted
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No active purchases")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Subscription options coming soon.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            } else if storeKit.isPremium {
                Section {
                    NavigationLink {
                        PremiumBenefitsView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("MyChannel Plus+")
                                    .font(.system(size: 17, weight: .semibold))
                                
                                Spacer()
                                
                                Text("Active")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            
                            Text("$4.99/month")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Active subscriptions")
                }
                
                Section {
                    Button("Manage subscription") {
                        // Open App Store subscriptions
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Button("Cancel subscription") {
                        // Open cancel flow
                    }
                    .foregroundColor(.red)
                }
            } else {
                Section {
                    NavigationLink {
                        MyChannelPlusView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MyChannel Plus+")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text("Try free for 7 days")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Available subscriptions")
                }
            }
        }
        .navigationTitle("Purchases and memberships")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HistorySettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        List {
            Section {
                Button("Clear watch history") {
                    Task {
                        await settingsService.clearWatchHistory()
                    }
                }
                
                Toggle(
                    "Pause watch history",
                    isOn: Binding(
                        get: { settingsService.appSettings.privacy.pauseWatchHistory },
                        set: { value in
                            settingsService.updateAppSettings { $0.privacy.pauseWatchHistory = value }
                        }
                    )
                )
            }
            
            Section {
                Button("Clear search history") {
                    settingsService.clearSearchHistory()
                }
                
                Toggle(
                    "Pause search history",
                    isOn: Binding(
                        get: { settingsService.appSettings.privacy.pauseSearchHistory },
                        set: { value in
                            settingsService.updateAppSettings { $0.privacy.pauseSearchHistory = value }
                        }
                    )
                )
            } footer: {
                if !settingsService.recentSearches().isEmpty {
                    Text("Recent searches stored on this device: \(settingsService.recentSearches().count)")
                }
            }
        }
        .navigationTitle("Manage all history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataSettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        List {
            Section {
                Button("Download your data") {
                    settingsService.updateAppSettings {
                        $0.history.lastDataExportRequest = Date()
                    }
                }
                
                Button("Delete specific data") {
                    settingsService.clearSearchHistory()
                    Task {
                        await settingsService.clearWatchHistory()
                    }
                }
            } footer: {
                if let lastExport = settingsService.appSettings.history.lastDataExportRequest {
                    Text("Last export requested \(lastExport.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    Text("Export requests are tracked so you can verify the last request from this device.")
                }
            }
        }
        .navigationTitle("Your data in MyChannel")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(
                    "Private profile",
                    isOn: Binding(
                        get: { settingsService.appSettings.privacy.privateProfile },
                        set: { value in
                            settingsService.updateAppSettings { $0.privacy.privateProfile = value }
                        }
                    )
                )
            } footer: {
                Text("When enabled, only people you approve can see your profile")
            }
            
            Section {
                Toggle(
                    "Show subscriptions",
                    isOn: Binding(
                        get: { settingsService.appSettings.privacy.showSubscriptions },
                        set: { value in
                            settingsService.updateAppSettings { $0.privacy.showSubscriptions = value }
                        }
                    )
                )
                Toggle(
                    "Show playlists",
                    isOn: Binding(
                        get: { settingsService.appSettings.privacy.showPlaylists },
                        set: { value in
                            settingsService.updateAppSettings { $0.privacy.showPlaylists = value }
                        }
                    )
                )
            } header: {
                Text("Profile visibility")
            }
            
            Section("Advertising") {
                Toggle(
                    "Personalized ads",
                    isOn: Binding(
                        get: { settingsService.appSettings.privacy.personalizedAds },
                        set: { value in
                            settingsService.updateAppSettings { $0.privacy.personalizedAds = value }
                        }
                    )
                )
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConnectedAppsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        List {
            Section {
                Toggle(
                    "Google",
                    isOn: Binding(
                        get: { settingsService.appSettings.connectedApps.googleConnected },
                        set: { value in
                            settingsService.updateAppSettings { $0.connectedApps.googleConnected = value }
                        }
                    )
                )
                Toggle(
                    "YouTube",
                    isOn: Binding(
                        get: { settingsService.appSettings.connectedApps.youtubeConnected },
                        set: { value in
                            settingsService.updateAppSettings { $0.connectedApps.youtubeConnected = value }
                        }
                    )
                )
                Toggle(
                    "Instagram",
                    isOn: Binding(
                        get: { settingsService.appSettings.connectedApps.instagramConnected },
                        set: { value in
                            settingsService.updateAppSettings { $0.connectedApps.instagramConnected = value }
                        }
                    )
                )
                Toggle(
                    "TikTok",
                    isOn: Binding(
                        get: { settingsService.appSettings.connectedApps.tiktokConnected },
                        set: { value in
                            settingsService.updateAppSettings { $0.connectedApps.tiktokConnected = value }
                        }
                    )
                )
            } header: {
                Text("Connected apps")
            } footer: {
                Text("These switches track the services linked to your MyChannel account on this device and sync when you are signed in.")
            }
        }
        .navigationTitle("Connected apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExperimentalFeaturesView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(
                    "AI-powered recommendations",
                    isOn: Binding(
                        get: { settingsService.appSettings.experimental.aiRecommendations },
                        set: { value in
                            settingsService.updateAppSettings { $0.experimental.aiRecommendations = value }
                        }
                    )
                )
                Toggle(
                    "Experimental video player",
                    isOn: Binding(
                        get: { settingsService.appSettings.experimental.experimentalPlayer },
                        set: { value in
                            settingsService.updateAppSettings { $0.experimental.experimentalPlayer = value }
                        }
                    )
                )
            } footer: {
                Text("These features are in beta and may not work as expected")
            }
        }
        .navigationTitle("Experimental features")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QualitySettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            Section {
                Picker(
                    "Video quality",
                    selection: Binding(
                        get: { settingsService.appSettings.videoQuality.wifiQuality },
                        set: { value in
                            settingsService.updateAppSettings { $0.videoQuality.wifiQuality = value }
                        }
                    )
                ) {
                    Text("Auto").tag(StreamingQualityOption.auto)
                    Text("1080p").tag(StreamingQualityOption.highest)
                    Text("720p").tag(StreamingQualityOption.high)
                    Text("480p").tag(StreamingQualityOption.medium)
                    Text("360p").tag(StreamingQualityOption.low)
                }
            } header: {
                Text("Wi-Fi")
            }
            
            Section {
                Picker(
                    "Mobile data usage",
                    selection: Binding(
                        get: { settingsService.appSettings.videoQuality.mobileUsage },
                        set: { value in
                            settingsService.updateAppSettings { $0.videoQuality.mobileUsage = value }
                        }
                    )
                ) {
                    Text("Auto").tag(MobileDataPreference.auto)
                    Text("Higher quality").tag(MobileDataPreference.higher)
                    Text("Data saver").tag(MobileDataPreference.saver)
                }
            } header: {
                Text("Mobile data")
            }
        }
        .navigationTitle("Quality")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Note: PlaybackSettingsView is defined in Features/Settings/PlaybackSettingsView.swift

struct BackgroundDownloadsView: View {
    @StateObject private var storeKit = StoreKitService.shared
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            if !AppConfig.Features.enableSubscriptions {
                // 🔥 FIX 2.1(b): Hide subscription upsell when IAPs not submitted
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background & Downloads")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Background play and downloads will be available with a future update.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            } else if storeKit.isPremium {
                Section {
                    Toggle(
                        "Background play",
                        isOn: Binding(
                            get: { settingsService.appSettings.playback.backgroundPlay },
                            set: { value in
                                settingsService.updateAppSettings { $0.playback.backgroundPlay = value }
                                BackgroundPlayService.shared.isBackgroundPlayEnabled = value
                            }
                        )
                    )
                } footer: {
                    Text("Keep videos playing when you switch apps")
                }
                
                Section {
                    NavigationLink {
                        DownloadsView()
                    } label: {
                        Text("Manage downloads")
                    }
                    
                    Picker(
                        "Download quality",
                        selection: Binding(
                            get: { settingsService.appSettings.downloads.downloadQuality },
                            set: { value in
                                settingsService.updateAppSettings { $0.downloads.downloadQuality = value }
                            }
                        )
                    ) {
                        Text("Low").tag(DownloadQualityPreference.low)
                        Text("Medium").tag(DownloadQualityPreference.medium)
                        Text("High").tag(DownloadQualityPreference.high)
                        Text("Highest").tag(DownloadQualityPreference.highest)
                    }
                } header: {
                    Text("Downloads")
                }
                
                Section("Offline behavior") {
                    Toggle(
                        "Download over Wi-Fi only",
                        isOn: Binding(
                            get: { settingsService.appSettings.downloads.wifiOnly },
                            set: { value in
                                settingsService.updateAppSettings { $0.downloads.wifiOnly = value }
                            }
                        )
                    )
                    Toggle(
                        "Smart downloads",
                        isOn: Binding(
                            get: { settingsService.appSettings.downloads.smartDownloads },
                            set: { value in
                                settingsService.updateAppSettings { $0.downloads.smartDownloads = value }
                            }
                        )
                    )
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storage limit: \(Int(settingsService.appSettings.downloads.storageLimitGB)) GB")
                            .font(.system(size: 15))
                        Slider(
                            value: Binding(
                                get: { settingsService.appSettings.downloads.storageLimitGB },
                                set: { value in
                                    settingsService.updateAppSettings { $0.downloads.storageLimitGB = value }
                                }
                            ),
                            in: 1...50,
                            step: 1
                        )
                    }
                    Button("Delete all downloads", role: .destructive) {
                        settingsService.deleteAllDownloads()
                    }
                }
            } else {
                Section {
                    NavigationLink {
                        MyChannelPlusView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unlock with Plus+")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Background play and downloads are available with MyChannel Plus+")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Background & downloads")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UploadsSettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            Section {
                Picker(
                    "Upload quality",
                    selection: Binding(
                        get: { settingsService.appSettings.uploads.uploadQuality },
                        set: { value in
                            settingsService.updateAppSettings { $0.uploads.uploadQuality = value }
                        }
                    )
                ) {
                    Text("4K").tag("4K")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                }
            }
            
            Section {
                Toggle(
                    "Upload over Wi-Fi only",
                    isOn: Binding(
                        get: { settingsService.appSettings.uploads.wifiOnly },
                        set: { value in
                            settingsService.updateAppSettings { $0.uploads.wifiOnly = value }
                        }
                    )
                )
            } footer: {
                Text("Recommended to avoid data charges")
            }
        }
        .navigationTitle("Uploads")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LiveChatSettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(
                    "Show live chat",
                    isOn: Binding(
                        get: { settingsService.appSettings.chat.showLiveChat },
                        set: { value in
                            settingsService.updateAppSettings { $0.chat.showLiveChat = value }
                        }
                    )
                )
                Toggle(
                    "Chat notifications",
                    isOn: Binding(
                        get: { settingsService.appSettings.chat.chatNotifications },
                        set: { value in
                            settingsService.updateAppSettings { $0.chat.chatNotifications = value }
                        }
                    )
                )
            }
        }
        .navigationTitle("Live chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WatchOnTVView: View {
    var body: some View {
        List {
            Section {
                Text("Connect your device")
                    .foregroundColor(.secondary)
            } footer: {
                Text("Cast videos to your TV using AirPlay or Chromecast")
            }
        }
        .navigationTitle("Watch on TV")
        .navigationBarTitleDisplayMode(.inline)
    }
}


#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
