//
//  OwnerCommandCenterView.swift
//  MyChannel
//
//  Owner-only command center — full YouTube department team working 24/7
//  Daily reports, fraud tracking, content moderation, user growth, platform health
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Owner Command Center

struct OwnerCommandCenterView: View {
    @StateObject private var vm = CommandCenterViewModel()
    @State private var selectedTab: CCTab = .briefing
    @State private var pulseAnimation = false

    enum CCTab: String, CaseIterable {
        case briefing  = "BRIEFING"
        case users     = "USERS"
        case fraud     = "FRAUD"
        case content   = "CONTENT"
        case reports   = "REPORTS"
        case livestreams = "LIVE"
        case ai        = "AI"
        case revenue   = "REVENUE"
        case system    = "SYSTEM"
        case executive = "EXEC"
    }

private struct CreatorPulseCard: View {
    let pulse: CreatorPulse
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pulse.creatorName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CCTheme.textPrimary)
                Spacer()
            }
            Text(pulse.status)
                .font(.system(size: 11))
                .foregroundColor(CCTheme.textSecondary)
            HStack {
                Label("Views", systemImage: "play.rectangle.fill")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
                Spacer()
                Text(pulse.viewsDelta)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(pulse.isSpike ? CCTheme.good : CCTheme.warning)
            }
            ProgressView(value: pulse.healthScore / 100)
                .tint(pulse.healthScore > 70 ? CCTheme.good : CCTheme.warning)
        }
        .padding(12)
        .frame(width: 220)
        .background(CCTheme.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}

private struct StrikeSnapshotRow: View {
    let snapshot: StrikeSnapshot
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CCTheme.textPrimary)
                    Text(snapshot.latestViolation)
                        .font(.system(size: 11))
                        .foregroundColor(CCTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Strikes: \(snapshot.strikeCount)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(snapshot.strikeCount >= 3 ? CCTheme.critical : CCTheme.warning)
                    Text("AI Risk \(snapshot.aiRisk)%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                }
            }
            .padding(12)
            .background(CCTheme.panel)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct OwnerTaskCard: View {
    let task: OwnerTask
    let onComplete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CCTheme.textPrimary)
                Text(task.detail)
                    .font(.system(size: 11))
                    .foregroundColor(CCTheme.textSecondary)
            }
            Spacer()
            Button(action: onComplete) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(CCTheme.good)
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}

    

    private var autopilotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("SELF-HEALING AUTOPILOT", systemImage: vm.autopilotStatus.isOnline ? "gearshape.2.fill" : "bolt.slash")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(vm.autopilotStatus.isOnline ? CCTheme.textPrimary : CCTheme.textSecondary)
                Spacer()
                Text(vm.autopilotStatus.lastSelfCheck, style: .time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
            }
            HStack(spacing: 16) {
                autopilotStat(title: "BUGS PATCHED", value: "\(vm.autopilotStatus.bugsPatchedToday)")
                autopilotStat(title: "AUTOFIX /HR", value: "\(vm.autopilotStatus.autopatchesLastHour)")
                autopilotStat(title: "PERF GAIN", value: "+\(String(format: "%.1f", vm.autopilotStatus.performanceGain))%")
                autopilotStat(title: "LATENCY", value: "-\(String(format: "%.1f", vm.autopilotStatus.avgLatencySavingsMs))ms")
            }
            .font(.system(size: 12, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Current Focus: \(vm.autopilotStatus.currentFocus)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CCTheme.textPrimary)
                ProgressView(value: vm.autopilotStatus.learningRate / 100) {
                    Text("Learning Rate".uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                }
                .tint(CCTheme.textPrimary)
                .scaleEffect(x: 1, y: 1.1, anchor: .center)
                Text("Telemetry events processed: \(vm.formatNumber(vm.autopilotStatus.telemetryEvents)) · Reliability \(String(format: "%.0f", vm.autopilotStatus.reliabilityScore))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
            }
        }
        .padding(16)
        .background(CCTheme.panel)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    private func autopilotStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(CCTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var creatorHealthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREATOR HEALTH FEED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(CCTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.creatorHealth) { pulse in
                        CreatorPulseCard(pulse: pulse)
                    }
                }
            }
        }
    }

    private var strikeSnapshotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("3-STRIKE SNAPSHOT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
                Spacer()
                Text("\(vm.strikeQueueCount) pending")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(vm.strikeQueueCount > 0 ? CCTheme.critical : CCTheme.good)
            }
            VStack(spacing: 8) {
                ForEach(vm.strikeSnapshots) { snapshot in
                    StrikeSnapshotRow(snapshot: snapshot) {
                        vm.focusStrikeCase(id: snapshot.caseId)
                    }
                }
            }
            NavigationLink(destination: StrikeReviewView()) {
                Text("OPEN FULL STRIKE REVIEW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(CCTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(CCTheme.panel)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(CCTheme.panelBorder, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(CCTheme.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    private var moderationInboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODERATION INBOX")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(CCTheme.textSecondary)
            VStack(spacing: 12) {
                ForEach(vm.openFraudAlerts.prefix(3)) { alert in
                    FraudAlertRow(alert: alert) {
                        vm.reviewFraudAlert(alert.id)
                    }
                }
                ForEach(vm.openContentFlags.prefix(3)) { flag in
                    ContentFlagRow(flag: flag) {
                        vm.reviewContentFlag(flag.id, action: .approve)
                    } onRemove: {
                        vm.reviewContentFlag(flag.id, action: .remove)
                    }
                }
            }
        }
        .padding(14)
        .background(CCTheme.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    private var ownerTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OWNER TASK QUEUE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
                Spacer()
                Button("Add Task") { vm.addSampleTask() }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CCTheme.textPrimary)
            }
            LazyVStack(spacing: 10) {
                ForEach(vm.ownerTasks) { task in
                    OwnerTaskCard(task: task) {
                        vm.completeTask(task.id)
                    }
                }
            }
        }
        .padding(14)
        .background(CCTheme.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            commandHeader
            // Tab bar
            tabBar
            // Content
            switch selectedTab {
            case .briefing:  briefingTab
            case .users:     usersTab
            case .fraud:     fraudTab
            case .content:   contentTab
            case .reports:   reportsTab
            case .livestreams: liveStreamsTab
            case .ai:        aiTab
            case .revenue:   revenueTab
            case .system:    systemTab
            case .executive: executiveTab
            }
        }
        .navigationTitle("⚡ COMMAND CENTER")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.startTracking()
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onDisappear { vm.stopTracking() }
    }

    // MARK: - Header

    private var commandHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(CCTheme.accent).frame(width: 6, height: 6)
                    .opacity(pulseAnimation ? 1.0 : 0.5)
                Text("MYCHANNEL OPERATIONS — OWNER ACCESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
            }
            HStack(spacing: 0) {
                CCHeaderStat(label: "TOTAL USERS", value: vm.formatNumber(vm.totalUsers), color: .white)
                CCHeaderStat(label: "TODAY", value: "+\(vm.formatNumber(vm.newUsersToday))", color: CCTheme.good)
                CCHeaderStat(label: "ACTIVE NOW", value: vm.formatNumber(vm.activeNow), color: .white)
                CCHeaderStat(label: "REVENUE/DAY", value: "$\(vm.formatNumber(vm.revenueToday))", color: CCTheme.good)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(CCTheme.ink)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(CCTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 4) {
                            if tab == .fraud && vm.fraudAlerts.contains(where: { !$0.reviewed }) {
                                Circle().fill(CCTheme.critical).frame(width: 6, height: 6)
                            }
                            if tab == .content && vm.contentFlags.contains(where: { !$0.reviewed }) {
                                Circle().fill(CCTheme.warning).frame(width: 6, height: 6)
                            }
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(selectedTab == tab ? CCTheme.textPrimary : CCTheme.textSecondary)
                        }
                        .frame(minWidth: 80)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? CCTheme.panelBorder : Color.clear)
                    }
                }
            }
        }
        .background(CCTheme.panel)
    }

    // MARK: - BRIEFING TAB

    private var briefingTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Platform Health Score
                platformHealthCard

                // Autopilot AI status
                autopilotCard

                // Key Metrics Grid
                metricsGrid

                // Creator Health Feed
                if !vm.creatorHealth.isEmpty {
                    creatorHealthSection
                }

                // Strike Snapshot
                if !vm.strikeSnapshots.isEmpty {
                    strikeSnapshotSection
                }

                // AI Daily Summary (enhanced)
                if !vm.dailySummary.isEmpty {
                    aiSummaryCard
                }

                // Fraud + Content Inbox
                if vm.hasOpenModerationItems {
                    moderationInboxSection
                }

                // Owner Task Queue
                if !vm.ownerTasks.isEmpty {
                    ownerTaskSection
                }

                // Department Status
                departmentStatusSection

                // Recent Events
                if !vm.recentEvents.isEmpty {
                    recentEventsCard
                }
            }
            .padding(16)
        }
    }

    private var platformHealthCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(CCTheme.panel)
            RoundedRectangle(cornerRadius: 16)
                .stroke(CCTheme.panelBorder, lineWidth: 1)
            VStack(spacing: 8) {
                HStack {
                    Text("PLATFORM HEALTH SCORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    Spacer()
                    Text(vm.platformHealth >= 80 ? "GOOD" : vm.platformHealth >= 60 ? "FAIR" : "NEEDS ATTENTION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(vm.platformHealth >= 80 ? CCTheme.good : vm.platformHealth >= 60 ? CCTheme.warning : CCTheme.critical)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(Int(vm.platformHealth))%")
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .foregroundColor(CCTheme.textPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Based on: uptime, fraud rate,")
                        Text("content safety, user growth,")
                        Text("revenue performance")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(CCTheme.panelBorder).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(vm.platformHealth >= 80 ? CCTheme.good : vm.platformHealth >= 60 ? CCTheme.warning : CCTheme.critical)
                            .frame(width: geo.size.width * vm.platformHealth / 100, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CCMetricCard(title: "TOTAL DOWNLOADS", value: vm.formatNumber(vm.totalDownloads), subtitle: "+\(vm.formatNumber(vm.newDownloadsToday)) today", color: CCTheme.textPrimary, icon: "arrow.down.circle.fill")
            CCMetricCard(title: "VIDEOS UPLOADED", value: vm.formatNumber(vm.videosUploaded), subtitle: "+\(vm.videosUploadedToday) today", color: CCTheme.textPrimary, icon: "video.circle.fill")
            CCMetricCard(title: "FRAUD BLOCKED", value: "\(vm.fraudAlerts.count)", subtitle: "\(vm.fraudAlerts.filter { !$0.reviewed }.count) unreviewed", color: vm.fraudAlerts.isEmpty ? CCTheme.good : CCTheme.critical, icon: "shield.slash.fill")
            CCMetricCard(title: "CONTENT FLAGS", value: "\(vm.contentFlags.count)", subtitle: "\(vm.contentFlags.filter { !$0.reviewed }.count) pending", color: vm.contentFlags.isEmpty ? CCTheme.good : CCTheme.warning, icon: "exclamationmark.triangle.fill")
            CCMetricCard(title: "AVG SESSION", value: "\(vm.avgSessionMinutes)m", subtitle: "per active user", color: CCTheme.textPrimary, icon: "timer")
            CCMetricCard(title: "CREATOR COUNT", value: vm.formatNumber(vm.creatorCount), subtitle: "+\(vm.newCreatorsToday) today", color: CCTheme.textPrimary, icon: "person.fill.checkmark")
            NavigationLink(destination: StrikeReviewView()) {
                CCMetricCard(title: "3-STRIKE QUEUE", value: "\(vm.strikeQueueCount)", subtitle: "\(vm.strikeQueueCount) awaiting your review", color: vm.strikeQueueCount > 0 ? CCTheme.critical : CCTheme.good, icon: "bolt.fill")
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(CCTheme.textSecondary)
                Text("AI DAILY BRIEFING")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
                Spacer()
                Text(vm.summaryGeneratedAt, style: .time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CCTheme.textSecondary)
            }
            Text(vm.dailySummary)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(CCTheme.textPrimary)
                .lineSpacing(4)

            Button {
                Task { await vm.generateDailyBriefing() }
            } label: {
                HStack {
                    if vm.isGeneratingBriefing { ProgressView().scaleEffect(0.7) }
                    else { Image(systemName: "arrow.clockwise") }
                    Text(vm.isGeneratingBriefing ? "GENERATING..." : "REFRESH BRIEFING")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(CCTheme.textPrimary)
            }
            .disabled(vm.isGeneratingBriefing)
        }
        .padding(14)
        .background(CCTheme.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    private var departmentStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEPARTMENT STATUS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(CCTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(vm.departments) { dept in
                    DepartmentRow(dept: dept)
                }
            }
        }
    }

    private var recentEventsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLATFORM EVENTS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(CCTheme.textSecondary)
            ForEach(vm.recentEvents.prefix(8)) { event in
                PlatformEventRow(event: event)
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
    }

    // MARK: - USERS TAB

    private var usersTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Total Users Banner
                ZStack {
                    CCTheme.ink
                    VStack(spacing: 6) {
                        Text("TOTAL APP DOWNLOADS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                        Text(vm.formatNumber(vm.totalDownloads))
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        HStack(spacing: 16) {
                            VStack {
                                Text("+\(vm.formatNumber(vm.newDownloadsToday))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.good)
                                Text("TODAY").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                            }
                            VStack {
                                Text("+\(vm.formatNumber(vm.newDownloadsWeek))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                Text("THIS WEEK").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                            }
                            VStack {
                                Text("+\(vm.formatNumber(vm.newDownloadsMonth))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                Text("THIS MONTH").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(.vertical, 24)
                }
                .cornerRadius(16)

                // User Breakdown
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    CCMetricCard(title: "REGISTERED USERS", value: vm.formatNumber(vm.totalUsers), subtitle: "accounts created", color: CCTheme.textPrimary, icon: "person.fill")
                    CCMetricCard(title: "ACTIVE TODAY", value: vm.formatNumber(vm.activeNow), subtitle: "currently in app", color: CCTheme.good, icon: "eye.fill")
                    CCMetricCard(title: "CREATORS", value: vm.formatNumber(vm.creatorCount), subtitle: "uploading content", color: CCTheme.textPrimary, icon: "video.fill")
                    CCMetricCard(title: "PAID SUBSCRIBERS", value: vm.formatNumber(vm.paidUsers), subtitle: "premium members", color: CCTheme.textPrimary, icon: "star.fill")
                    CCMetricCard(title: "DAY 1 RETENTION", value: "\(vm.day1Retention)%", subtitle: "come back next day", color: CCTheme.textPrimary, icon: "return")
                    CCMetricCard(title: "DAY 7 RETENTION", value: "\(vm.day7Retention)%", subtitle: "weekly retention", color: CCTheme.textPrimary, icon: "calendar")
                }

                // Top Countries
                if !vm.topCountries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TOP COUNTRIES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CCTheme.textSecondary)
                        ForEach(vm.topCountries.prefix(5)) { country in
                            HStack {
                                Text(country.flag).font(.system(size: 20))
                                Text(country.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(CCTheme.textPrimary)
                                Spacer()
                                Text(vm.formatNumber(country.users) + " users")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(CCTheme.textSecondary)
                                Text("\(country.percent)%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(CCTheme.textPrimary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(CCTheme.panel)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CCTheme.panelBorder, lineWidth: 1))
                        }
                    }
                }

                // Refresh button
                refreshButton { Task { await vm.refreshUserData() } }
            }
            .padding(16)
        }
    }

    // MARK: - FRAUD TAB

    private var fraudTab: some View {
        VStack(spacing: 0) {
            // Fraud Status Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FRAUD DETECTION SYSTEM")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    Text("\(vm.fraudAlerts.filter { !$0.reviewed }.count) ACTIVE ALERTS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(vm.fraudAlerts.contains(where: { !$0.reviewed }) ? CCTheme.critical : CCTheme.good)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BLOCKED TODAY")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                    Text("$\(vm.formatNumber(vm.fraudBlockedAmount))")
                        .font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(CCTheme.panel)

            if vm.fraudAlerts.isEmpty {
                Spacer()
                Image(systemName: "shield.checkered")
                    .font(.system(size: 56)).foregroundColor(CCTheme.textSecondary.opacity(0.5))
                Text("ALL CLEAR").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                Text("No fraud detected").font(.system(size: 13, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.fraudAlerts) { alert in
                            FraudAlertRow(alert: alert) {
                                vm.reviewFraudAlert(alert.id)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - CONTENT TAB

    private var contentTab: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTENT MODERATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    Text("\(vm.contentFlags.filter { !$0.reviewed }.count) PENDING REVIEW")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(vm.contentFlags.contains(where: { !$0.reviewed }) ? CCTheme.warning : CCTheme.good)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REMOVED TODAY")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                    Text("\(vm.contentRemovedToday)")
                        .font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(CCTheme.panel)

            if vm.contentFlags.isEmpty {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56)).foregroundColor(CCTheme.textSecondary.opacity(0.5))
                Text("CLEAN PLATFORM").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                Text("No inappropriate content flagged").font(.system(size: 13, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.contentFlags) { flag in
                            ContentFlagRow(flag: flag) {
                                vm.reviewContentFlag(flag.id, action: .approve)
                            } onRemove: {
                                vm.reviewContentFlag(flag.id, action: .remove)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - REPORTS TAB

    private var reportsTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Generate Report Button
                Button {
                    Task { await vm.generateDailyReport() }
                } label: {
                    HStack {
                        if vm.isGeneratingReport {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text.fill")
                        }
                        Text(vm.isGeneratingReport ? "GENERATING REPORT..." : "GENERATE TODAY'S REPORT")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(vm.isGeneratingReport ? CCTheme.neutral : CCTheme.ink)
                    .foregroundColor(.white).cornerRadius(12)
                }
                .disabled(vm.isGeneratingReport)

                // Reports List
                if vm.dailyReports.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.system(size: 48)).foregroundColor(CCTheme.textSecondary.opacity(0.4))
                        Text("No reports yet").font(.system(size: 14, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        Text("Tap above to generate your first daily report").font(.system(size: 12)).foregroundColor(CCTheme.textSecondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(vm.dailyReports) { report in
                        DailyReportCard(report: report)
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - LIVE STREAMS TAB
    
    private var liveStreamsTab: some View {
        LiveStreamsCommandCenterView()
    }
    
    // MARK: - AI TAB
    
    private var aiTab: some View {
        AICommandCenterView()
    }
    
    // MARK: - REVENUE TAB
    
    private var revenueTab: some View {
        RevenueCommandCenterView()
    }
    
    // MARK: - SYSTEM TAB
    
    private var systemTab: some View {
        SystemCommandCenterView()
    }
    
    // MARK: - EXECUTIVE TAB
    
    private var executiveTab: some View {
        ExecutiveCommandCenterView()
    }

    // MARK: - Helpers

    private func refreshButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("REFRESH DATA")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(CCTheme.textPrimary)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(CCTheme.panel).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CCTheme.panelBorder, lineWidth: 1))
        }
    }
}


// ⚡ Supporting views + ViewModel extracted to CommandCenterViews.swift
