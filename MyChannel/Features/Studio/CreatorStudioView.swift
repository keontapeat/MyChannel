//
//  CreatorStudioView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct CreatorStudioView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .overview
    
    enum Tab: Hashable { case overview, earnings, content, memberships, analytics, community, premieres }

    // Deep link initializer
    init(startOn tab: Tab = .overview) {
        _selectedTab = State(initialValue: tab)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                AnalyticsOverviewContainer()
                    .tabItem { Label("Overview", systemImage: "chart.bar.xaxis") }
                    .tag(Tab.overview)
                
                EarningsDashboardView()
                    .tabItem { Label("Earnings", systemImage: "dollarsign.circle") }
                    .tag(Tab.earnings)
                
                NavigationStack { StudioContentList().toolbar { NavigationLink("Bulk Edit") { ContentBulkEditView() } } }
                    .tabItem { Label("Content", systemImage: "list.bullet.rectangle") }
                    .tag(Tab.content)

                NavigationStack { MembershipsManagerView() }
                    .tabItem { Label("Memberships", systemImage: "person.badge.plus") }
                    .tag(Tab.memberships)
                
                NavigationStack { 
                    List {
                        ForEach(Video.sampleVideos.prefix(5)) { video in
                            NavigationLink {
                                VideoAnalyticsView(videoId: video.id)
                            } label: {
                                Text(video.title).lineLimit(1)
                            }
                        }
                    }
                    .navigationTitle("Video Analytics")
                }
                    .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(Tab.analytics)
                
                NavigationStack { 
                    if let creatorId = appState.currentUser?.id {
                        CommunityPostsView(creatorId: creatorId)
                    }
                }
                    .tabItem { Label("Community", systemImage: "person.3") }
                    .tag(Tab.community)
                
                NavigationStack {
                    if let creatorId = appState.currentUser?.id {
                        ScheduledPremieresView(creatorId: creatorId)
                    }
                }
                    .tabItem { Label("Premieres", systemImage: "calendar.badge.clock") }
                    .tag(Tab.premieres)
            }
            .navigationTitle("Creator Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AlertsCenterView()) {
                        Image(systemName: "bell.badge")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareCurrentTab) {
                        Image(systemName: "link").accessibilityLabel("Copy Studio Link")
                    }
                }
            }
            .overlay(alignment: .top) {
                StudioOnboardingChecklist()
                    .padding(.top, 8)
            }
        }
    }

    private func shareCurrentTab() {
        let tabMap: [Tab: String] = [
            .overview: "overview", 
            .earnings: "earnings", 
            .content: "content", 
            .memberships: "memberships",
            .analytics: "analytics",
            .community: "community",
            .premieres: "premieres"
        ]
        let url = URL(string: "mychannel://studio?tab=\(tabMap[selectedTab] ?? "overview")")!
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.topMostController()?.present(av, animated: true)
    }
}

private struct StudioContentList: View {
    @State private var videos: [Video] = Array(Video.sampleVideos.prefix(20))
    
    var body: some View {
        List {
            ForEach(videos) { v in
                HStack(spacing: 12) {
                    MultiSourceAsyncImage(
                        urls: v.posterCandidates,
                        content: { $0.resizable().scaledToFill() },
                        placeholder: { Color(.systemGray6) }
                    )
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(v.title).font(.subheadline).fontWeight(.semibold).lineLimit(2)
                        HStack(spacing: 8) {
                            Label("\(v.formattedViewCount)", systemImage: "eye")
                            Label(v.formattedDuration, systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .listStyle(.plain)
    }
}

#Preview("Creator Studio") {
    CreatorStudioView()
        .environmentObject(AppState())
}


