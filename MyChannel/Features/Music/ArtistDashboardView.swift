//
//  ArtistDashboardView.swift
//  MyChannel
//
//  Complete Artist Dashboard - Shows all music, listeners, analytics, earnings, distribution, content ID in one place
//  Like DistroKid but better
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ArtistDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: DashboardTab = .overview
    @State private var isLoading = true
    @State private var artistId: String = ""
    @State private var showUploadSheet = false
    @State private var showDistributionSheet = false
    @State private var showPayoutSheet = false
    @State private var showVerificationSheet = false
    @State private var showContentIDSheet = false
    @State private var showProfileEditSheet = false
    @State private var selectedContentPolicy: ContentMatch.MatchPolicy = .track
    
    // Overview data
    @State private var totalTracks: Int = 0
    @State private var totalStreams: Int = 0
    @State private var totalEarnings: Double = 0
    @State private var currentListeners: Int = 0
    @State private var pendingPayout: Double = 0
    @State private var payoutAccountConnected = false
    
    // Music tracks
    @State private var tracks: [ArtistTrack] = []
    
    // Distribution
    @State private var distributionStatus: [PlatformDistribution] = []
    @State private var payoutRequests: [PayoutRequest] = []
    @State private var topLocations: [AnalyticsBreakdown] = []
    @State private var deviceBreakdown: [AnalyticsBreakdown] = []
    
    // Content ID
    @State private var contentIdMatches: Int = 0
    @State private var contentIdRevenue: Double = 0
    @State private var protectedTracksCount: Int = 0
    
    // Verification
    @State private var verificationStatus: String = "not_submitted"
    
    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case music = "Music"
        case analytics = "Analytics"
        case earnings = "Earnings"
        case distribution = "Distribution"
        case contentId = "Content ID"
    }
    
    struct ArtistTrack: Identifiable {
        let id: String
        let title: String
        let album: String?
        let genre: String
        let streamCount: Int
        let status: String
        let artworkURL: String?
        let audioURL: String?
        let uploadedAt: Date
    }
    
    struct PlatformDistribution: Identifiable {
        let id: String
        let platform: String
        let trackTitle: String?
        let status: String
        let submittedAt: Date?
        let releaseDate: Date?
    }

    struct AnalyticsBreakdown: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    struct PayoutRequest: Identifiable {
        let id: String
        let amount: Double
        let payoutMethod: String
        let status: String
        let requestedAt: Date?
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                header
                
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            overviewTab
                        case .music:
                            musicTab
                        case .analytics:
                            analyticsTab
                        case .earnings:
                            earningsTab
                        case .distribution:
                            distributionTab
                        case .contentId:
                            contentIdTab
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadDashboardData() }
            .sheet(isPresented: $showUploadSheet, onDismiss: {
                Task { await loadDashboardData() }
            }) {
                MusicUploadSheet()
            }
            .sheet(isPresented: $showDistributionSheet) {
                NavigationStack {
                    MusicDistributionRequestSheet(
                        artistId: artistId,
                        tracks: trackOptions,
                        onSubmitted: {
                            Task {
                                await loadDistributionStatus()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showPayoutSheet) {
                NavigationStack {
                    ArtistPayoutRequestSheet(
                        artistId: artistId,
                        availableAmount: pendingPayout,
                        payoutAccountConnected: payoutAccountConnected,
                        onSubmitted: {
                            Task {
                                await loadPayoutData()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showVerificationSheet) {
                NavigationStack {
                    ArtistVerificationRequestSheet(
                        artistId: artistId,
                        displayName: appState.currentUser?.displayName ?? "",
                        email: appState.currentUser?.email ?? "",
                        onSubmitted: {
                            Task {
                                await loadVerificationStatus()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showContentIDSheet) {
                NavigationStack {
                    ContentIDEnrollmentSheet(
                        artistId: artistId,
                        artistName: appState.currentUser?.displayName ?? "",
                        tracks: trackOptions,
                        defaultPolicy: selectedContentPolicy,
                        onSubmitted: {
                            Task {
                                await loadContentIdData()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showProfileEditSheet) {
                NavigationStack {
                    ArtistProfileEditSheet(
                        artistId: artistId,
                        currentDisplayName: appState.currentUser?.displayName ?? "",
                        onSubmitted: {
                            Task {
                                await loadDashboardData()
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Group {
                    if let urlString = appState.currentUser?.profileImageURL,
                       let url = URL(string: urlString) {
                        AppAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color(.systemGray5))
                        }
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artist Dashboard")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let displayName = appState.currentUser?.displayName {
                        Text(displayName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Edit profile button
                Button {
                    showProfileEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(8)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Verification badge
                verificationBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var verificationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: verificationBadgeIcon)
                .font(.system(size: 14))
            Text(verificationBadgeTitle)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(verificationBadgeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(verificationBadgeColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring()) {
                            selectedTab = tab
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.blue : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        VStack(spacing: 20) {
            // Quick stats
            VStack(spacing: 16) {
                statCard(title: "Total Tracks", value: "\(totalTracks)", icon: "music.note.list", color: .blue)
                statCard(title: "Total Streams", value: formatNumber(totalStreams), icon: "waveform", color: .green)
                statCard(title: "Current Listeners", value: "\(currentListeners)", icon: "person.2.fill", color: .purple)
                statCard(title: "Total Earnings", value: formatCurrency(totalEarnings), icon: "dollarsign.circle.fill", color: .orange)
            }
            
            // Quick actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    quickActionButton(title: "Upload New Track", icon: "plus.circle.fill", color: .blue) {
                        showUploadSheet = true
                    }
                    quickActionButton(title: "Request Payout", icon: "arrow.down.circle.fill", color: .green) {
                        showPayoutSheet = true
                    }
                    quickActionButton(title: "Distribute to Platforms", icon: "arrow.up.circle.fill", color: .orange) {
                        showDistributionSheet = true
                    }
                    quickActionButton(title: "Manage Content ID", icon: "fingerprint", color: .purple) {
                        selectedContentPolicy = .track
                        showContentIDSheet = true
                    }
                }
            }

            if !isArtistVerified {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verification")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    quickActionButton(title: verificationStatus == "submitted" ? "Verification Pending Review" : "Submit Verification", icon: "checkmark.seal.fill", color: .indigo) {
                        if verificationStatus != "submitted" {
                            showVerificationSheet = true
                        }
                    }
                }
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.shared.impact(style: .medium)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Music Tab
    
    private var musicTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Music")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    showUploadSheet = true
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Upload")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
            }
            
            if tracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No tracks yet")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("Upload your first track to get started")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 12) {
                    ForEach(tracks) { track in
                        trackRow(track)
                    }
                }
            }
        }
    }
    
    private func trackRow(_ track: ArtistTrack) -> some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURL = track.artworkURL, let url = URL(string: artworkURL) {
                AppAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let album = track.album {
                    Text(album)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Text(track.genre)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(formatNumber(track.streamCount) + " streams")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(track.status == "published" ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(track.status.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(track.status == "published" ? .green : .orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((track.status == "published" ? Color.green : Color.orange).opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Analytics Tab
    
    private var analyticsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Real-Time Analytics")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            // Live listeners
            VStack(alignment: .leading, spacing: 12) {
                Text("Live Listeners")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(currentListeners)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                    Text("listening now")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Locations")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if topLocations.isEmpty {
                    analyticsEmptyState("Location data will appear after listeners stream your music.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(topLocations.prefix(5).enumerated()), id: \.element.id) { index, item in
                            locationRow(country: item.label, count: item.count, total: topLocations.reduce(0) { $0 + $1.count }, color: analyticsColor(at: index))
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Device Breakdown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if deviceBreakdown.isEmpty {
                    analyticsEmptyState("Device mix appears once playback events start coming in.")
                } else {
                    HStack(spacing: 12) {
                        ForEach(Array(deviceBreakdown.prefix(3).enumerated()), id: \.element.id) { index, item in
                            deviceRow(icon: deviceIcon(for: item.label), name: item.label, count: item.count, total: deviceBreakdown.reduce(0) { $0 + $1.count }, color: analyticsColor(at: index))
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func locationRow(country: String, count: Int, total: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(country)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("\(percentage(for: count, total: total))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                ProgressView(value: Double(count), total: Double(max(total, 1)))
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(width: 80)
            }
        }
    }
    
    private func deviceRow(icon: String, name: String, count: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(percentage(for: count, total: total))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func analyticsEmptyState(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Earnings Tab
    
    private var earningsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Earnings")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            // Total earnings card
            VStack(alignment: .leading, spacing: 16) {
                Text("Total Earnings")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(formatCurrency(totalEarnings))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pending")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatCurrency(pendingPayout))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rate")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Text("$0.004/stream")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Payout options
            VStack(alignment: .leading, spacing: 12) {
                Text("Payout Options")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    payoutOptionCard(title: "Instant Payout", description: payoutAccountConnected ? "1-2 business days" : "Connect payouts first", fee: "1.5% fee", color: .green) {
                        showPayoutSheet = true
                    }
                    payoutOptionCard(title: "Standard Payout", description: payoutAccountConnected ? "5-7 business days" : "Connect payouts first", fee: "No fee", color: .blue) {
                        showPayoutSheet = true
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !payoutRequests.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Requests")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 10) {
                        ForEach(payoutRequests.prefix(5)) { request in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatCurrency(request.amount))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(request.payoutMethod.capitalized)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(request.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(request.status == "completed" ? .green : .orange)
                            }
                            .padding(12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func payoutOptionCard(title: String, description: String, fee: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.shared.impact(style: .medium)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(fee)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(color)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Distribution Tab
    
    private var distributionTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Distribution")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    showDistributionSheet = true
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Distribute")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
            }
            
            // Supported platforms
            VStack(alignment: .leading, spacing: 12) {
                Text("Supported Platforms")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 10) {
                    platformRow(name: "Spotify", icon: "music.note", color: .green)
                    platformRow(name: "Apple Music", icon: "music.note", color: .red)
                    platformRow(name: "YouTube Music", icon: "play.rectangle", color: .red)
                    platformRow(name: "Amazon Music", icon: "music.note", color: .blue)
                    platformRow(name: "Tidal", icon: "music.note", color: .black)
                    platformRow(name: "Deezer", icon: "music.note", color: .purple)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Distribution status (if any)
            if !distributionStatus.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Distribution Status")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 10) {
                        ForEach(distributionStatus) { dist in
                            distributionRow(dist)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func platformRow(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("Supported")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func distributionRow(_ dist: PlatformDistribution) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dist.platform)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                if let trackTitle = dist.trackTitle, !trackTitle.isEmpty {
                    Text(trackTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                if let releaseDate = dist.releaseDate {
                    Text("Release \(releaseDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(distributionStatusColor(for: dist.status))
                    .frame(width: 8, height: 8)
                Text(dist.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(distributionStatusColor(for: dist.status))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Content ID Tab
    
    private var contentIdTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Content ID")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Content ID Overview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("\(protectedTracksCount)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.purple)
                        Text("Protected")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 8) {
                        Text("\(contentIdMatches)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Matches")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text(formatCurrency(contentIdRevenue))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        Text("Revenue")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Register Existing Track")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        selectedContentPolicy = .track
                        showContentIDSheet = true
                    } label: {
                        Text("Enroll")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }

                Text("Choose a default enforcement policy when enrolling an uploaded track.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                VStack(spacing: 10) {
                    policyOptionCard(title: "Copyright Strike", description: "Block unauthorized usage", icon: "exclamationmark.triangle.fill", color: .red, policy: .block)
                    policyOptionCard(title: "Revenue Share", description: "Allow usage + earn revenue", icon: "dollarsign.circle.fill", color: .green, policy: .monetize)
                    policyOptionCard(title: "Allow Usage", description: "Track usage without blocking it", icon: "checkmark.circle.fill", color: .blue, policy: .track)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func policyOptionCard(title: String, description: String, icon: String, color: Color, policy: ContentMatch.MatchPolicy) -> some View {
        Button {
            selectedContentPolicy = policy
            showContentIDSheet = true
            HapticManager.shared.impact(style: .medium)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Data Loading
    
    private func loadDashboardData() async {
        isLoading = true
        
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid {
            artistId = uid
            await loadTracks()

            async let analyticsTask = loadAnalytics()
            async let distributionTask = loadDistributionStatus()
            async let contentIdTask = loadContentIdData()
            async let verificationTask = loadVerificationStatus()
            async let payoutTask = loadPayoutData()

            _ = await (analyticsTask, distributionTask, contentIdTask, verificationTask, payoutTask)
        }
        #endif
        
        isLoading = false
    }
    
    private func loadTracks() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("music_tracks")
                .whereField("artistId", isEqualTo: artistId)
                .getDocuments()

            let loadedTracks = snapshot.documents.compactMap { doc in
                let data = doc.data()
                let uploadedAt = (data["uploadedAt"] as? Timestamp)?.dateValue()
                    ?? (data["createdAt"] as? Timestamp)?.dateValue()
                    ?? Date()
                let albumValue = (data["album"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let albumNameValue = (data["albumName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let statusValue = data["status"] as? String
                    ?? (((data["isPublished"] as? Bool) ?? false) ? "published" : "draft")
                let streamCount = (data["streamCount"] as? Int)
                    ?? Int((data["streamCount"] as? Int64) ?? 0)
                return ArtistTrack(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    album: !(albumNameValue ?? "").isEmpty ? albumNameValue : albumValue,
                    genre: data["genre"] as? String ?? "",
                    streamCount: streamCount,
                    status: statusValue,
                    artworkURL: data["artworkURL"] as? String,
                    audioURL: (data["audioURL"] as? String) ?? (data["streamURL"] as? String),
                    uploadedAt: uploadedAt
                )
            }

            tracks = loadedTracks.sorted { $0.uploadedAt > $1.uploadedAt }
            totalTracks = tracks.count
            totalStreams = tracks.reduce(0) { $0 + $1.streamCount }
        } catch {
            print("Error loading tracks: \(error)")
        }
        #endif
    }
    
    private func loadAnalytics() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let thirtyDaysAgo = Date().addingTimeInterval(-2_592_000)
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            let playsSnapshot = try await db.collection("music_plays")
                .whereField("artistId", isEqualTo: artistId)
                .whereField("playedAt", isGreaterThan: Timestamp(date: thirtyDaysAgo))
                .getDocuments()

            let playDocuments = playsSnapshot.documents.map { $0.data() }
            let recentListenerIds = Set(playDocuments.compactMap { data -> String? in
                guard let timestamp = data["playedAt"] as? Timestamp,
                      timestamp.dateValue() >= fiveMinutesAgo else { return nil }
                return data["listenerId"] as? String
            })
            currentListeners = recentListenerIds.count

            topLocations = aggregateBreakdown(from: playDocuments, primaryKey: "country", fallbackKey: "countryCode")
            deviceBreakdown = aggregateBreakdown(from: playDocuments, primaryKey: "deviceType")
        } catch {
            print("Error loading analytics: \(error)")
            currentListeners = 0
            topLocations = []
            deviceBreakdown = []
        }
        #else
        currentListeners = 0
        topLocations = []
        deviceBreakdown = []
        #endif
    }

    private func loadPayoutData() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        do {
            let grossEstimated = Double(totalStreams) * 0.004

            let accountDoc = try? await db.collection("artist_stripe").document(artistId).getDocument()
            let accountData = accountDoc?.data()
            payoutAccountConnected = (accountData?["connected"] as? Bool)
                ?? ((accountData?["stripeAccountId"] as? String)?.isEmpty == false)

            let payoutSnapshot = try await db.collection("artist_payouts")
                .whereField("artistId", isEqualTo: artistId)
                .getDocuments()

            let completedPayoutTotal = payoutSnapshot.documents.reduce(0.0) { partial, doc in
                let data = doc.data()
                let status = data["status"] as? String ?? ""
                let amount = data["amount"] as? Double ?? Double(data["amount"] as? Int ?? 0)
                return status == "completed" || status == "paid" ? partial + amount : partial
            }

            let requestSnapshot = try await db.collection("music_payout_requests")
                .whereField("artistId", isEqualTo: artistId)
                .getDocuments()

            payoutRequests = requestSnapshot.documents.compactMap { doc in
                let data = doc.data()
                let amount = data["finalAmount"] as? Double
                    ?? data["amount"] as? Double
                    ?? Double(data["finalAmount"] as? Int ?? data["amount"] as? Int ?? 0)
                return PayoutRequest(
                    id: doc.documentID,
                    amount: amount,
                    payoutMethod: data["payoutType"] as? String ?? data["payoutMethod"] as? String ?? "standard",
                    status: data["status"] as? String ?? "pending",
                    requestedAt: (data["requestedAt"] as? Timestamp)?.dateValue()
                )
            }
            .sorted { ($0.requestedAt ?? .distantPast) > ($1.requestedAt ?? .distantPast) }

            totalEarnings = grossEstimated
            pendingPayout = max(0, grossEstimated - completedPayoutTotal)
        } catch {
            print("Error loading payout data: \(error)")
            payoutAccountConnected = false
            payoutRequests = []
            totalEarnings = Double(totalStreams) * 0.004
            pendingPayout = totalEarnings
        }
        #else
        payoutAccountConnected = false
        payoutRequests = []
        totalEarnings = Double(totalStreams) * 0.004
        pendingPayout = totalEarnings
        #endif
    }
    
    private func loadDistributionStatus() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("music_distribution")
                .whereField("artistId", isEqualTo: artistId)
                .getDocuments()

            distributionStatus = snapshot.documents.flatMap { doc in
                let data = doc.data()
                let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
                let releaseDate = (data["releaseDate"] as? Timestamp)?.dateValue()

                if let platformStatuses = data["platformStatuses"] as? [String: [String: Any]], !platformStatuses.isEmpty {
                    return platformStatuses.map { platform, platformData in
                        PlatformDistribution(
                            id: "\(doc.documentID)_\(platform)",
                            platform: platform,
                            trackTitle: data["trackTitle"] as? String,
                            status: platformData["status"] as? String ?? data["overallStatus"] as? String ?? "pending",
                            submittedAt: (platformData["submittedAt"] as? Timestamp)?.dateValue() ?? submittedAt,
                            releaseDate: releaseDate
                        )
                    }
                }

                return [
                    PlatformDistribution(
                        id: doc.documentID,
                        platform: data["platform"] as? String ?? "Unknown",
                        trackTitle: data["trackTitle"] as? String,
                        status: data["status"] as? String ?? data["overallStatus"] as? String ?? "pending_review",
                        submittedAt: submittedAt,
                        releaseDate: releaseDate
                    )
                ]
            }
            .sorted { ($0.submittedAt ?? .distantPast) > ($1.submittedAt ?? .distantPast) }
        } catch {
            print("Error loading distribution status: \(error)")
            distributionStatus = []
        }
        #else
        distributionStatus = []
        #endif
    }
    
    private func loadContentIdData() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            // Try app-side collections first
            let referenceSnapshot = try await db.collection("content_id_references")
                .whereField("ownerId", isEqualTo: artistId)
                .getDocuments()

            let matchesSnapshot = try await db.collection("content_matches")
                .whereField("ownerId", isEqualTo: artistId)
                .getDocuments()

            let usageSnapshot = try await db.collection("content_usage_tracking")
                .whereField("ownerId", isEqualTo: artistId)
                .getDocuments()

            var protectedCount = referenceSnapshot.documents.count
            var matchesCount = matchesSnapshot.documents.count
            var revenueTotal = usageSnapshot.documents.reduce(0.0) { sum, doc in
                let data = doc.data()
                let revenue = data["revenue"] as? Double ?? 0.0
                return sum + revenue
            }
            
            // Fallback to backend music_content_id collection if app collections empty
            if protectedCount == 0 {
                let backendSnapshot = try await db.collection("music_content_id")
                    .whereField("artistId", isEqualTo: artistId)
                    .getDocuments()
                protectedCount = backendSnapshot.documents.count
                
                // Also check for matches/revenue in backend format
                let backendMatchesSnapshot = try await db.collection("music_content_id")
                    .whereField("artistId", isEqualTo: artistId)
                    .whereField("matchCount", isGreaterThan: 0)
                    .getDocuments()
                matchesCount = max(matchesCount, backendMatchesSnapshot.documents.count)
            }

            protectedTracksCount = protectedCount
            contentIdMatches = matchesCount
            contentIdRevenue = revenueTotal
        } catch {
            print("Error loading content ID data: \(error)")
            protectedTracksCount = 0
            contentIdMatches = 0
            contentIdRevenue = 0.0
        }
        #else
        protectedTracksCount = 0
        contentIdMatches = 0
        contentIdRevenue = 0.0
        #endif
    }
    
    private func loadVerificationStatus() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            if appState.currentUser?.isVerified == true {
                verificationStatus = "verified"
                return
            }

            let userDoc = try? await db.collection("users").document(artistId).getDocument()
            if let status = userDoc?.data()?["verificationStatus"] as? String {
                verificationStatus = status
                return
            }

            let doc = try await db.collection("artist_verification").document(artistId).getDocument()
            if let data = doc.data(), let status = data["status"] as? String {
                verificationStatus = status
            } else {
                verificationStatus = "not_submitted"
            }
        } catch {
            print("Error loading verification status: \(error)")
            verificationStatus = appState.currentUser?.isVerified == true ? "verified" : "not_submitted"
        }
        #endif
    }
    
    // MARK: - Helpers

    private var trackOptions: [ArtistDashboardTrackOption] {
        tracks.map {
            ArtistDashboardTrackOption(id: $0.id, title: $0.title, audioURL: $0.audioURL)
        }
    }

    private var isArtistVerified: Bool {
        ["approved", "verified"].contains(verificationStatus.lowercased())
    }

    private var verificationBadgeIcon: String {
        switch verificationStatus.lowercased() {
        case "approved", "verified":
            return "checkmark.seal.fill"
        case "submitted", "pending_review", "pendingreview":
            return "clock.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private var verificationBadgeTitle: String {
        switch verificationStatus.lowercased() {
        case "approved", "verified":
            return "Verified"
        case "submitted", "pending_review", "pendingreview":
            return "Pending"
        default:
            return "Not Verified"
        }
    }

    private var verificationBadgeColor: Color {
        switch verificationStatus.lowercased() {
        case "approved", "verified":
            return .green
        case "submitted", "pending_review", "pendingreview":
            return .blue
        default:
            return .orange
        }
    }

    private func aggregateBreakdown(from documents: [[String: Any]], primaryKey: String, fallbackKey: String? = nil) -> [AnalyticsBreakdown] {
        let counts = documents.reduce(into: [String: Int]()) { partial, data in
            let rawValue = (data[primaryKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackValue = fallbackKey.flatMap { key in
                (data[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let label = rawValue?.isEmpty == false ? rawValue! : (fallbackValue ?? "")
            guard !label.isEmpty else { return }
            partial[label, default: 0] += 1
        }

        return counts
            .map { AnalyticsBreakdown(id: $0.key, label: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func percentage(for count: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total) * 100).rounded())
    }

    private func analyticsColor(at index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .gray]
        return colors[index % colors.count]
    }

    private func distributionStatusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "approved", "live", "delivered":
            return .green
        case "rejected", "failed":
            return .red
        default:
            return .orange
        }
    }

    private func deviceIcon(for label: String) -> String {
        switch label.lowercased() {
        case let value where value.contains("iphone") || value.contains("ios"):
            return "iphone"
        case let value where value.contains("ipad"):
            return "ipad"
        case let value where value.contains("mac") || value.contains("desktop"):
            return "desktopcomputer"
        case let value where value.contains("tv"):
            return "tv"
        default:
            return "headphones"
        }
    }
    
    private func formatNumber(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
}
