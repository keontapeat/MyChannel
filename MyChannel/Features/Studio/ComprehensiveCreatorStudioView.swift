//
//  ComprehensiveCreatorStudioView.swift
//  MyChannel
//
//  Complete YouTube Studio parity with advanced features
//  Every feature YouTube Studio has + revolutionary AI enhancements
//

import SwiftUI
import Charts

struct ComprehensiveCreatorStudioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var analyticsService = AdvancedAnalyticsService.shared
    @StateObject var aiCoCreator = AIVideoCoCreatorService.shared
    @StateObject var predictiveEngine = PredictiveAnalyticsEngine.shared
    
    let videoIdToAnalyze: String? // Optional video ID to focus on when opening
    @Environment(\.dismiss) private var dismiss
    @State var selectedTab: StudioTab = .dashboard
    @State var showingUploadModal = false
    @State var selectedVideoId: String? = nil
    
    init(videoId: String? = nil) {
        self.videoIdToAnalyze = videoId
    }
    
    enum StudioTab: String, CaseIterable, Hashable {
        case dashboard = "Dashboard"
        case aiStudio = "AI Studio"
        case content = "Content"
        case analytics = "Analytics"
        case earnings = "Earnings"
        case customization = "Customization"
        case community = "Community"
        case premieres = "Premieres"
        case live = "Live"
        case flicks = "Flicks"
        case playlists = "Playlists"
        case copyright = "Copyright"
        case monetization = "Monetization"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.xaxis"
            case .aiStudio: return "lightbulb"
            case .content: return "play.rectangle"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .earnings: return "dollarsign.circle"
            case .customization: return "paintbrush"
            case .community: return "person.3"
            case .premieres: return "calendar.badge.clock"
            case .live: return "dot.radiowaves.left.and.right"
            case .flicks: return "rectangle.portrait"
            case .playlists: return "list.bullet.rectangle"
            case .copyright: return "shield.checkered"
            case .monetization: return "banknote"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        // 🔥 MOBILE-FIRST CREATOR STUDIO: Always show main content on mobile
        mainContentArea
            .navigationTitle("Creator Studio")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        // Back / close button
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                        .accessibilityLabel("Back")
                        
                        // 🔥 MOBILE NAVIGATION: Studio sections menu
                        Menu {
                            ForEach(StudioTab.allCases, id: \.self) { tab in
                                Button(action: { 
                                    selectedTab = tab
                                    HapticManager.shared.impact(style: .light)
                                }) {
                                    Label(tab.rawValue, systemImage: tab.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: selectedTab.icon)
                                    .font(.system(size: 16, weight: .medium))
                                Text(selectedTab.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // Upload Button
                        Button(action: { 
                            HapticManager.shared.impact(style: .medium)
                            showingUploadModal = true 
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .accessibilityLabel("Upload video")
                        
                        // Notifications
                        NavigationLink(destination: NotificationsView()) {
                            Image(systemName: "bell")
                                .font(.system(size: 16))
                        }
                        .accessibilityLabel("Notifications")
                    }
            }
            .fullScreenCover(isPresented: $showingUploadModal) {
            UploadView()
                .environmentObject(appState)
        }
        .safeAreaInset(edge: .bottom) {
            // 🔥 MOBILE QUICK TABS: Bottom navigation for key sections
            mobileQuickTabs
        }
        .onAppear {
            // If videoId provided, navigate to content tab and select that video
            if let videoId = videoIdToAnalyze {
                selectedTab = .content
                selectedVideoId = videoId
            }
            
            // Load initial analytics data
            Task {
                if let creatorId = appState.currentUser?.id {
                    await analyticsService.startRealtimeMonitoring(for: creatorId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenVideoInStudio"))) { notification in
            if let videoId = notification.object as? String {
                selectedTab = .content
                selectedVideoId = videoId
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCreatorStudio"))) { notification in
            // 🔥 REAL-TIME ANALYTICS REFRESH: Update when new video uploaded
            Task {
                if let creatorId = appState.currentUser?.id {
                    await analyticsService.startRealtimeMonitoring(for: creatorId)
                }
                
                // Add new video to analytics tracking
                if let video = notification.object as? Video {
                    let analytics = VideoAnalytics(
                        videoId: video.id,
                        views: video.viewCount,
                        uniqueViews: video.viewCount,
                        likes: video.likeCount,
                        dislikes: video.dislikeCount,
                        comments: video.commentCount,
                        shares: 0,
                        watchTime: 0,
                        averageWatchTime: 0,
                        clickThroughRate: 0,
                        engagementRate: 0,
                        revenue: 0
                    )
                    await analyticsService.addVideoAnalytics(analytics)
                }
            }
        }
    }
    
    // MARK: - Sidebar Navigation
    
    private var sidebarNavigation: some View {
        List(StudioTab.allCases, id: \.self) { tab in
            NavigationLink(destination: destinationView(for: tab)) {
                HStack(spacing: 12) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 20)
                    
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Badge for notifications
                    if tab == .community && hasNewComments {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                    }
                    
                    if tab == .copyright && hasCopyrightClaims {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 4)
            }
            .simultaneousGesture(TapGesture().onEnded {
                selectedTab = tab
                HapticManager.shared.impact(style: .light)
            })
        }
        .listStyle(.sidebar)
        .navigationTitle("Studio")
    }
    
    // MARK: - Navigation Destination
    
    @ViewBuilder
    func destinationView(for tab: StudioTab) -> some View {
        switch tab {
        case .dashboard:
            // 🔥 NUCLEAR: Use the new YouTube-parity dashboard
            NuclearYouTubeStudioDashboard()
                .navigationTitle("Dashboard")
        case .aiStudio:
            AICreatorStudioView()
                .navigationTitle("AI Studio")
        case .content:
            ContentManagementView()
                .navigationTitle("Content")
        case .analytics:
            AdvancedAnalyticsView()
                .navigationTitle("Analytics")
        case .earnings:
            // 🔥 FIX 3.1.1: Gate external payment features
            if AppConfig.Features.enableCreatorMonetization {
                EarningsManagementView()
                    .navigationTitle("Earnings")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Earnings Coming Soon")
                        .font(.title3.bold())
                    Text("Creator monetization will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .navigationTitle("Earnings")
            }
        case .customization:
            ChannelCustomizationView()
                .navigationTitle("Customization")
        case .community:
            // 🔥 NUCLEAR: Full YouTube-parity comments management
            NuclearCommentsManagementView()
                .navigationTitle("Community")
        case .premieres:
            PremieresManagementView()
                .navigationTitle("Premieres")
        case .live:
            LiveStreamingStudioView()
                .navigationTitle("Live")
        case .flicks:
            FlicksStudioView()
                .navigationTitle("Flicks")
        case .playlists:
            PlaylistManagementView()
                .navigationTitle("Playlists")
        case .copyright:
            CopyrightManagementView()
                .navigationTitle("Copyright")
        case .monetization:
            MonetizationStudioView()
                .navigationTitle("Monetization")
        case .settings:
            StudioSettingsView()
                .navigationTitle("Settings")
        }
    }
    
    // MARK: - Main Content Area
    
    @ViewBuilder
    private var mainContentArea: some View {
        switch selectedTab {
        case .dashboard:
            // 🔥 NUCLEAR: Use the new YouTube-parity dashboard
            NuclearYouTubeStudioDashboard()
        case .aiStudio:
            AICreatorStudioView()
        case .content:
            ContentManagementView()
        case .analytics:
            AdvancedAnalyticsView()
        case .earnings:
            // 🔥 FIX 3.1.1: Gate external payment features
            if AppConfig.Features.enableCreatorMonetization {
                EarningsManagementView()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Earnings Coming Soon")
                        .font(.title3.bold())
                    Text("Creator monetization will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        case .customization:
            ChannelCustomizationView()
        case .community:
            // 🔥 NUCLEAR: Full YouTube-parity comments management  
            NuclearCommentsManagementView()
        case .premieres:
            PremieresManagementView()
        case .live:
            LiveStreamingStudioView()
        case .flicks:
            FlicksStudioView()
        case .playlists:
            PlaylistManagementView()
        case .copyright:
            CopyrightManagementView()
        case .monetization:
            MonetizationStudioView()
        case .settings:
            StudioSettingsView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasNewComments: Bool {
        false
    }
    
    private var hasCopyrightClaims: Bool {
        false
    }
}

