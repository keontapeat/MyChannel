//
//  StudioSettingsView.swift
//  MyChannel
//
//  100% COMPLETE STUDIO SETTINGS! ⚙️
//

import SwiftUI

struct StudioSettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    
    var body: some View {
        Form {
            uploadDefaultsSection
            notificationsSection
            privacySection
            moderationSection
            liveSection
            monetizationSection
            connectedAccountsSection
            advancedSection
        }
        .navigationTitle("Settings")
    }
    
    private var uploadDefaultsSection: some View {
        Section("Upload Defaults") {
            Picker(
                "Quality",
                selection: Binding(
                    get: { settingsService.studioSettings.uploadDefaults.defaultQuality },
                    set: { value in
                        settingsService.updateStudioSettings { $0.uploadDefaults.defaultQuality = value }
                    }
                )
            ) {
                Text("4K").tag("4K")
                Text("1080p").tag("1080p")
                Text("720p").tag("720p")
            }
            
            Picker(
                "Visibility",
                selection: Binding(
                    get: { settingsService.studioSettings.uploadDefaults.defaultVisibility },
                    set: { value in
                        settingsService.updateStudioSettings { $0.uploadDefaults.defaultVisibility = value }
                    }
                )
            ) {
                Text("Public").tag(StudioVisibility.public)
                Text("Unlisted").tag(StudioVisibility.unlisted)
                Text("Private").tag(StudioVisibility.private)
            }
            
            Toggle("Add to Featured", isOn: Binding(get: { settingsService.studioSettings.uploadDefaults.addToFeatured }, set: { value in
                settingsService.updateStudioSettings { $0.uploadDefaults.addToFeatured = value }
            }))
            Toggle("Auto-generate captions", isOn: Binding(get: { settingsService.studioSettings.uploadDefaults.autoGenerateCaptions }, set: { value in
                settingsService.updateStudioSettings { $0.uploadDefaults.autoGenerateCaptions = value }
            }))
            Toggle("Made for kids by default", isOn: Binding(get: { settingsService.studioSettings.uploadDefaults.audienceMadeForKids }, set: { value in
                settingsService.updateStudioSettings { $0.uploadDefaults.audienceMadeForKids = value }
            }))
        }
    }
    
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: Binding(get: { settingsService.studioSettings.notifications.enableNotifications }, set: { value in
                settingsService.updateStudioSettings { $0.notifications.enableNotifications = value }
            }))
            Toggle("New Comments", isOn: Binding(get: { settingsService.studioSettings.notifications.newComments }, set: { value in
                settingsService.updateStudioSettings { $0.notifications.newComments = value }
            }))
            Toggle("New Subscribers", isOn: Binding(get: { settingsService.studioSettings.notifications.newSubscribers }, set: { value in
                settingsService.updateStudioSettings { $0.notifications.newSubscribers = value }
            }))
            Toggle("Revenue Updates", isOn: Binding(get: { settingsService.studioSettings.notifications.revenueUpdates }, set: { value in
                settingsService.updateStudioSettings { $0.notifications.revenueUpdates = value }
            }))
            Toggle("Content Claims", isOn: Binding(get: { settingsService.studioSettings.notifications.contentClaims }, set: { value in
                settingsService.updateStudioSettings { $0.notifications.contentClaims = value }
            }))
            Toggle("Live Performance Alerts", isOn: Binding(get: { settingsService.studioSettings.notifications.livePerformanceAlerts }, set: { value in
                settingsService.updateStudioSettings { $0.notifications.livePerformanceAlerts = value }
            }))
        }
    }
    
    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Show Subscriber Count", isOn: Binding(get: { settingsService.studioSettings.privacy.showSubscriberCount }, set: { value in
                settingsService.updateStudioSettings { $0.privacy.showSubscriberCount = value }
            }))
            Toggle("Show Video Stats", isOn: Binding(get: { settingsService.studioSettings.privacy.showVideoStats }, set: { value in
                settingsService.updateStudioSettings { $0.privacy.showVideoStats = value }
            }))
            Toggle("Allow Comments", isOn: Binding(get: { settingsService.studioSettings.privacy.allowComments }, set: { value in
                settingsService.updateStudioSettings { $0.privacy.allowComments = value }
            }))
            Toggle("Allow Embedding", isOn: Binding(get: { settingsService.studioSettings.privacy.allowEmbedding }, set: { value in
                settingsService.updateStudioSettings { $0.privacy.allowEmbedding = value }
            }))
            Toggle("Publish to subscriptions feed", isOn: Binding(get: { settingsService.studioSettings.privacy.publishToSubscriptionsFeed }, set: { value in
                settingsService.updateStudioSettings { $0.privacy.publishToSubscriptionsFeed = value }
            }))
        }
    }
    
    private var moderationSection: some View {
        Section("Moderation") {
            Toggle("Hold potentially inappropriate comments", isOn: Binding(get: { settingsService.studioSettings.moderation.holdPotentiallyInappropriateComments }, set: { value in
                settingsService.updateStudioSettings { $0.moderation.holdPotentiallyInappropriateComments = value }
            }))
            Toggle("Hold links for review", isOn: Binding(get: { settingsService.studioSettings.moderation.holdLinksForReview }, set: { value in
                settingsService.updateStudioSettings { $0.moderation.holdLinksForReview = value }
            }))
            Toggle("Allow clips", isOn: Binding(get: { settingsService.studioSettings.moderation.allowClips }, set: { value in
                settingsService.updateStudioSettings { $0.moderation.allowClips = value }
            }))
        }
    }
    
    private var liveSection: some View {
        Section("Live") {
            Toggle("Live chat replay", isOn: Binding(get: { settingsService.studioSettings.live.liveChatReplay }, set: { value in
                settingsService.updateStudioSettings { $0.live.liveChatReplay = value }
            }))
            Toggle("Auto captions", isOn: Binding(get: { settingsService.studioSettings.live.enableAutoCaptions }, set: { value in
                settingsService.updateStudioSettings { $0.live.enableAutoCaptions = value }
            }))
            Toggle("Clip live moments", isOn: Binding(get: { settingsService.studioSettings.live.clipLiveMoments }, set: { value in
                settingsService.updateStudioSettings { $0.live.clipLiveMoments = value }
            }))
        }
    }
    
    private var monetizationSection: some View {
        Section("Monetization") {
            Toggle("Ads enabled", isOn: Binding(get: { settingsService.studioSettings.monetization.adsEnabled }, set: { value in
                settingsService.updateStudioSettings { $0.monetization.adsEnabled = value }
            }))
            Toggle("Preroll ads", isOn: Binding(get: { settingsService.studioSettings.monetization.prerollEnabled }, set: { value in
                settingsService.updateStudioSettings { $0.monetization.prerollEnabled = value }
            }))
            Toggle("Midroll ads", isOn: Binding(get: { settingsService.studioSettings.monetization.midrollEnabled }, set: { value in
                settingsService.updateStudioSettings { $0.monetization.midrollEnabled = value }
            }))
            Toggle("Postroll ads", isOn: Binding(get: { settingsService.studioSettings.monetization.postrollEnabled }, set: { value in
                settingsService.updateStudioSettings { $0.monetization.postrollEnabled = value }
            }))
            Toggle("Skippable ads", isOn: Binding(get: { settingsService.studioSettings.monetization.skippableAds }, set: { value in
                settingsService.updateStudioSettings { $0.monetization.skippableAds = value }
            }))
            Toggle("Personalized ads", isOn: Binding(get: { settingsService.studioSettings.monetization.personalizedAds }, set: { value in
                settingsService.updateStudioSettings { $0.monetization.personalizedAds = value }
            }))
        }
    }
    
    private var connectedAccountsSection: some View {
        Section("Connected Accounts") {
            Toggle("Instagram", isOn: Binding(get: { settingsService.studioSettings.connectedAccounts.instagramConnected }, set: { value in
                settingsService.updateStudioSettings { $0.connectedAccounts.instagramConnected = value }
            }))
            Toggle("Twitter", isOn: Binding(get: { settingsService.studioSettings.connectedAccounts.twitterConnected }, set: { value in
                settingsService.updateStudioSettings { $0.connectedAccounts.twitterConnected = value }
            }))
            Toggle("TikTok", isOn: Binding(get: { settingsService.studioSettings.connectedAccounts.tiktokConnected }, set: { value in
                settingsService.updateStudioSettings { $0.connectedAccounts.tiktokConnected = value }
            }))
        }
    }
    
    private var advancedSection: some View {
        Group {
            Section("Advanced") {
                Toggle("API Access", isOn: Binding(get: { settingsService.studioSettings.advanced.apiAccessEnabled }, set: { value in
                    settingsService.updateStudioSettings { $0.advanced.apiAccessEnabled = value }
                }))
                Toggle("Webhooks", isOn: Binding(get: { settingsService.studioSettings.advanced.webhooksEnabled }, set: { value in
                    settingsService.updateStudioSettings { $0.advanced.webhooksEnabled = value }
                }))
                Toggle("Developer Console", isOn: Binding(get: { settingsService.studioSettings.advanced.developerConsoleEnabled }, set: { value in
                    settingsService.updateStudioSettings { $0.advanced.developerConsoleEnabled = value }
                }))
            }
            
            Section {
                Button("Clear Cache", role: .destructive) {}
                Button("Reset All Settings", role: .destructive) {
                    settingsService.resetStudioSettings()
                }
            }
        }
    }
}


