import SwiftUI
import AVKit
import Combine

// MARK: - Premieres Management View
struct PremieresManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var premieresService = ScheduledPremieresService.shared
    @State private var showingScheduleView = false
    @State private var selectedFilter: PremiereFilter = .all
    
    enum PremiereFilter: String, CaseIterable {
        case all = "All"
        case scheduled = "Scheduled"
        case live = "Live Now"
        case completed = "Completed"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video Premieres")
                                .font(.system(size: 22, weight: .bold))
                            Text("Build hype and watch together with your audience")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { showingScheduleView = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Schedule")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(PremiereFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(
                        title: "Scheduled",
                        value: "\(filteredPremieres.filter { $0.status == .scheduled }.count)",
                        icon: "calendar.badge.clock",
                        color: .blue
                    )
                    StatBox(
                        title: "Live Now",
                        value: "\(filteredPremieres.filter { $0.status == .live }.count)",
                        icon: "dot.radiowaves.left.and.right",
                        color: .red
                    )
                    StatBox(
                        title: "Completed",
                        value: "\(filteredPremieres.filter { $0.status == .completed }.count)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
                .padding(.horizontal)
                
                // Premieres List
                if filteredPremieres.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Premieres Yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Schedule your first premiere to build anticipation")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(action: { showingScheduleView = true }) {
                            Text("Schedule Premiere")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPremieres) { premiere in
                            PremiereCard(premiere: premiere)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Help Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Premiere Tips")
                        .font(.system(size: 18, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        TipRow(
                            icon: "calendar.badge.clock",
                            text: "Schedule at least 24 hours in advance for maximum reach"
                        )
                        TipRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            text: "Enable chat to interact with viewers during the premiere"
                        )
                        TipRow(
                            icon: "bell.fill",
                            text: "Your subscribers will get notifications when it starts"
                        )
                        TipRow(
                            icon: "star.fill",
                            text: "Use countdown timer to build anticipation"
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            if let creatorId = appState.currentUser?.id {
                premieresService.listenToPremieres(creatorId: creatorId)
            }
        }
        .onDisappear {
            premieresService.stopListening()
        }
        .sheet(isPresented: $showingScheduleView) {
            if let creatorId = appState.currentUser?.id {
                SchedulePremiereView(creatorId: creatorId)
            }
        }
    }
    
    private var filteredPremieres: [ScheduledPremiere] {
        switch selectedFilter {
        case .all:
            return premieresService.premieres
        case .scheduled:
            return premieresService.premieres.filter { $0.status == .scheduled }
        case .live:
            return premieresService.premieres.filter { $0.status == .live }
        case .completed:
            return premieresService.premieres.filter { $0.status == .completed }
        }
    }
}

struct PremiereCard: View {
    let premiere: ScheduledPremiere
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: premiere.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            .overlay(
                // Status Badge
                HStack {
                    Circle()
                        .fill(premiere.status == .live ? Color.red : premiere.status == .scheduled ? Color.blue : Color.green)
                        .frame(width: 8, height: 8)
                    Text(premiere.status.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.8))
                .cornerRadius(6)
                .padding(6),
                alignment: .topLeading
            )
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(premiere.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(formatDate(premiere.scheduledAt))
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
                
                if premiere.status == .live, let viewerCount = premiere.viewerCount {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                        Text("\(viewerCount) watching")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.red)
                }
                
                if premiere.chatEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                        Text("Chat enabled")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct MonetizationStudioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @State private var selectedTab: MonetizationTab = .overview
    @State private var globalMonetizationEnabled = true
    @State private var adSettings = AdSettings()
    @State private var membershipSettings = MembershipSettings()
    @State private var merchandiseSettings = MerchandiseSettings()
    
    enum MonetizationTab: String, CaseIterable {
        case overview = "Overview"
        case ads = "Ads"
        case memberships = "Memberships"
        case merchandise = "Merchandise"
        case donations = "Super Chat"
        case analytics = "Revenue Analytics"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .ads: return "play.rectangle.fill"
            case .memberships: return "person.badge.plus.fill"
            case .merchandise: return "bag.fill"
            case .donations: return "heart.fill"
            case .analytics: return "dollarsign.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Tab Selector
            VStack(spacing: 12) {
                // Tab Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MonetizationTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                                HapticManager.shared.impact(style: .light)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                    Text(tab.rawValue)
                                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                                }
                                .frame(minWidth: 90)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(AppTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.1), lineWidth: selectedTab == tab ? 2 : 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Main Content
            Group {
                switch selectedTab {
                case .overview:
                    MonetizationOverviewView()
                case .ads:
                    AdMonetizationView(settings: $adSettings)
                case .memberships:
                    MembershipMonetizationView(settings: $membershipSettings)
                case .merchandise:
                    MerchandiseMonetizationView(settings: $merchandiseSettings)
                case .donations:
                    DonationMonetizationView()
                case .analytics:
                    RevenueAnalyticsView()
                }
            }
        }
        .onAppear {
            loadMonetizationSettings()
        }
    }
    
    private func loadMonetizationSettings() {
        // Load settings from backend or UserDefaults
        globalMonetizationEnabled = UserDefaults.standard.bool(forKey: "monetization_enabled")
        adSettings = AdSettings.load()
        membershipSettings = MembershipSettings.load()
        merchandiseSettings = MerchandiseSettings.load()
    }
}

