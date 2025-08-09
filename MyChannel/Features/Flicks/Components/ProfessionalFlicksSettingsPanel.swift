import SwiftUI

struct ProfessionalFlicksSettingsPanel: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flicks_video_quality") private var videoQuality: String = "Auto"
    @AppStorage("flicks_playback_speed") private var playbackSpeed: Double = 1.0
    @AppStorage("flicks_content_category") private var contentCategory: String = "For You"
    @AppStorage("flicks_feed_type") private var feedType: String = "For You"
    @AppStorage("flicks_auto_play") private var autoPlayNext: Bool = true
    @AppStorage("flicks_data_saver") private var dataSaverMode: Bool = false
    @AppStorage("flicks_captions") private var showCaptions: Bool = false
    
    private let videoQualities = ["Auto", "720p", "1080p", "4K"]
    private let playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let contentCategories = ["For You", "Gaming", "Music", "Comedy", "Tech", "Sports", "Education", "Art", "Food", "Travel"]
    private let feedTypes = ["For You", "Following", "Trending"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.3))
                            .frame(width: 50, height: 5)
                            .padding(.top, 12)
                        
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primary)
                            
                            Text("Flicks Settings")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    VStack(spacing: 24) {
                        SettingsSection(
                            title: "Feed Preferences",
                            icon: "rectangle.stack.fill",
                            iconColor: AppTheme.Colors.primary
                        ) {
                            VStack(spacing: 16) {
                                SettingsPicker(
                                    title: "Feed Type",
                                    selection: $feedType,
                                    options: feedTypes,
                                    icon: "list.bullet"
                                )
                                
                                SettingsPicker(
                                    title: "Content Category",
                                    selection: $contentCategory,
                                    options: contentCategories,
                                    icon: "tag.fill"
                                )
                            }
                        }
                        
                        SettingsSection(
                            title: "Video & Playback",
                            icon: "play.rectangle.fill",
                            iconColor: .blue
                        ) {
                            VStack(spacing: 16) {
                                SettingsPicker(
                                    title: "Video Quality",
                                    selection: $videoQuality,
                                    options: videoQualities,
                                    icon: "4k.tv"
                                )
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "speedometer")
                                            .foregroundStyle(.orange)
                                            .frame(width: 20)
                                        
                                        Text("Playback Speed")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(playbackSpeed, specifier: "%.2f")x")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(playbackSpeeds, id: \.self) { speed in
                                            Button("\(speed, specifier: speed == 1.0 ? "%.0f" : "%.2f")x") {
                                                playbackSpeed = speed
                                                HapticManager.shared.impact(style: .light)
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(playbackSpeed == speed ? .white : AppTheme.Colors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                playbackSpeed == speed ? AppTheme.Colors.primary : AppTheme.Colors.surface,
                                                in: Capsule()
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        SettingsSection(
                            title: "Preferences",
                            icon: "gearshape.fill",
                            iconColor: .purple
                        ) {
                            VStack(spacing: 16) {
                                SettingsToggle(
                                    title: "Auto-play Next Video",
                                    subtitle: "Automatically play the next video",
                                    isOn: $autoPlayNext,
                                    icon: "play.fill"
                                )
                                
                                SettingsToggle(
                                    title: "Data Saver Mode",
                                    subtitle: "Use less data by reducing video quality",
                                    isOn: $dataSaverMode,
                                    icon: "wifi.slash"
                                )
                                
                                SettingsToggle(
                                    title: "Show Captions",
                                    subtitle: "Display closed captions when available",
                                    isOn: $showCaptions,
                                    icon: "captions.bubble"
                                )
                            }
                        }
                        
                        SettingsSection(
                            title: "Quick Actions",
                            icon: "bolt.fill",
                            iconColor: .yellow
                        ) {
                            VStack(spacing: 12) {
                                FlicksQuickActionButton(
                                    title: "Clear Watch History",
                                    subtitle: "Reset your viewing recommendations",
                                    icon: "trash.fill",
                                    color: .red
                                ) {
                                    HapticManager.shared.impact(style: .medium)
                                }
                                
                                FlicksQuickActionButton(
                                    title: "Refresh Feed",
                                    subtitle: "Get fresh content recommendations",
                                    icon: "arrow.clockwise",
                                    color: .green
                                ) {
                                    HapticManager.shared.impact(style: .medium)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SettingsPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(selection)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            selection = option
                            HapticManager.shared.impact(style: .light)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? .white : AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selection == option ? AppTheme.Colors.primary : AppTheme.Colors.surface,
                            in: Capsule()
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                .onChange(of: isOn) { _, _ in
                    HapticManager.shared.impact(style: .light)
                }
        }
    }
}

#Preview {
    ProfessionalFlicksSettingsPanel()
        .preferredColorScheme(.dark)
}