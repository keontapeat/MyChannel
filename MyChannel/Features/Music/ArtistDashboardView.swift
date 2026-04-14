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
    
    // Overview data
    @State private var totalTracks: Int = 0
    @State private var totalStreams: Int = 0
    @State private var totalEarnings: Double = 0
    @State private var currentListeners: Int = 0
    @State private var pendingPayout: Double = 0
    
    // Music tracks
    @State private var tracks: [ArtistTrack] = []
    
    // Distribution
    @State private var distributionStatus: [PlatformDistribution] = []
    
    // Content ID
    @State private var contentIdMatches: Int = 0
    @State private var contentIdRevenue: Double = 0
    
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
        let status: String
        let submittedAt: Date?
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
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                    )
                
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
            Image(systemName: verificationStatus == "approved" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text(verificationStatus == "approved" ? "Verified" : "Not Verified")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(verificationStatus == "approved" ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((verificationStatus == "approved" ? Color.green : Color.orange).opacity(0.1))
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
                    quickActionButton(title: "Upload New Track", icon: "plus.circle.fill", color: .blue)
                    quickActionButton(title: "Request Payout", icon: "arrow.down.circle.fill", color: .green)
                    quickActionButton(title: "Distribute to Platforms", icon: "arrow.up.circle.fill", color: .orange)
                    quickActionButton(title: "View Content ID", icon: "fingerprint", color: .purple)
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
    
    private func quickActionButton(title: String, icon: String, color: Color) -> some View {
        Button {
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
            
            // Geographic distribution (mock)
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Locations")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 10) {
                    locationRow(country: "United States", percentage: 45, color: .blue)
                    locationRow(country: "United Kingdom", percentage: 18, color: .green)
                    locationRow(country: "Canada", percentage: 12, color: .orange)
                    locationRow(country: "Germany", percentage: 10, color: .purple)
                    locationRow(country: "Other", percentage: 15, color: .gray)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Device breakdown (mock)
            VStack(alignment: .leading, spacing: 12) {
                Text("Device Breakdown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    deviceRow(icon: "iphone", name: "iOS", percentage: 55, color: .blue)
                    deviceRow(icon: "android", name: "Android", percentage: 35, color: .green)
                    deviceRow(icon: "desktopcomputer", name: "Desktop", percentage: 10, color: .orange)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func locationRow(country: String, percentage: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(country)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("\(percentage)%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                ProgressView(value: Double(percentage), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(width: 80)
            }
        }
    }
    
    private func deviceRow(icon: String, name: String, percentage: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(percentage)%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    payoutOptionCard(title: "Instant Payout", description: "1-2 business days", fee: "$1.00 fee", color: .green)
                    payoutOptionCard(title: "Standard Payout", description: "5-7 business days", fee: "No fee", color: .blue)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func payoutOptionCard(title: String, description: String, fee: String, color: Color) -> some View {
        Button {
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
            
            Text("0% fee")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func distributionRow(_ dist: PlatformDistribution) -> some View {
        HStack(spacing: 12) {
            Text(dist.platform)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(dist.status == "approved" ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(dist.status.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(dist.status == "approved" ? .green : .orange)
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
            
            // Content ID overview
            VStack(alignment: .leading, spacing: 16) {
                Text("Content ID Overview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
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
            
            // Copyright policy options
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Copyright Policy")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 10) {
                    policyOptionCard(title: "Copyright Strike", description: "Block unauthorized usage", icon: "exclamationmark.triangle.fill", color: .red)
                    policyOptionCard(title: "Revenue Share", description: "Allow usage + earn % of revenue", icon: "dollarsign.circle.fill", color: .green)
                    policyOptionCard(title: "Allow Usage", description: "Free to use", icon: "checkmark.circle.fill", color: .blue)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func policyOptionCard(title: String, description: String, icon: String, color: Color) -> some View {
        Button {
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
            
            // Load tracks
            await loadTracks()
            
            // Load analytics
            await loadAnalytics()
            
            // Load distribution status
            await loadDistributionStatus()
            
            // Load content ID data
            await loadContentIdData()
            
            // Load verification status
            await loadVerificationStatus()
        }
        #endif
        
        isLoading = false
    }
    
    private func loadTracks() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("music_tracks")
                .where("artistId", "==", artistId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            tracks = snapshot.documents.compactMap { doc in
                let data = doc.data()
                return ArtistTrack(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    album: data["albumName"] as? String,
                    genre: data["genre"] as? String ?? "",
                    streamCount: data["streamCount"] as? Int ?? 0,
                    status: data["status"] as? String ?? "uploading",
                    artworkURL: data["artworkURL"] as? String,
                    audioURL: data["audioURL"] as? String,
                    uploadedAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            
            totalTracks = tracks.count
            totalStreams = tracks.reduce(0) { $0 + $1.streamCount }
        } catch {
            print("Error loading tracks: \(error)")
        }
        #endif
    }
    
    private func loadAnalytics() async {
        // Mock data for now - will connect to real analytics API
        currentListeners = Int.random(in: 10...100)
        totalEarnings = Double(totalStreams) * 0.004
        pendingPayout = totalEarnings
    }
    
    private func loadDistributionStatus() async {
        // Mock data for now
    }
    
    private func loadContentIdData() async {
        // Mock data for now
        contentIdMatches = Int.random(in: 0...50)
        contentIdRevenue = Double.random(in: 0...500)
    }
    
    private func loadVerificationStatus() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("artist_verification").document(artistId).getDocument()
            if let data = doc.data(), let status = data["status"] as? String {
                verificationStatus = status
            }
        } catch {
            print("Error loading verification status: \(error)")
        }
        #endif
    }
    
    // MARK: - Helpers
    
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
