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
                Spacer()
                Text(pulse.trendEmoji)
            }
            Text(pulse.status)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            HStack {
                Label("Views", systemImage: "play.rectangle.fill")
                    .font(.system(size: 10, design: .monospaced))
                Spacer()
                Text(pulse.viewsDelta)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(pulse.isSpike ? .green : .orange)
            }
            ProgressView(value: pulse.healthScore / 100)
                .tint(pulse.healthScore > 70 ? .green : .orange)
        }
        .padding(12)
        .frame(width: 220)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    Text(snapshot.latestViolation)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Strikes: \(snapshot.strikeCount)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(snapshot.strikeCount >= 3 ? .red : .orange)
                    Text("AI Risk \(snapshot.aiRisk)%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
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
                Text(task.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onComplete) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

    

    private var autopilotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("SELF-HEALING AUTOPILOT", systemImage: vm.autopilotStatus.isOnline ? "sparkles" : "bolt.slash")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(vm.autopilotStatus.isOnline ? .cyan : .secondary)
                Spacer()
                Text(vm.autopilotStatus.lastSelfCheck, style: .time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
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
                ProgressView(value: vm.autopilotStatus.learningRate / 100) {
                    Text("Learning Rate".uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .tint(.cyan)
                .scaleEffect(x: 1, y: 1.1, anchor: .center)
                Text("Telemetry events processed: \(vm.formatNumber(vm.autopilotStatus.telemetryEvents)) · Reliability \(String(format: "%.0f", vm.autopilotStatus.reliabilityScore))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.cyan.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
    }

    private func autopilotStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).foregroundColor(.cyan)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var creatorHealthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREATOR HEALTH FEED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(vm.strikeQueueCount) pending")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(vm.strikeQueueCount > 0 ? .red : .green)
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }

    private var moderationInboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODERATION INBOX")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var ownerTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OWNER TASK QUEUE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Add Task") { vm.addSampleTask() }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
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
        .background(Color.cyan.opacity(0.05))
        .cornerRadius(12)
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
                Circle().fill(Color.cyan).frame(width: 7, height: 7)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                Text("MYCHANNEL OPERATIONS — OWNER ACCESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.8))
            }
            HStack(spacing: 0) {
                CCHeaderStat(label: "TOTAL USERS", value: vm.formatNumber(vm.totalUsers), color: .cyan)
                CCHeaderStat(label: "TODAY", value: "+\(vm.formatNumber(vm.newUsersToday))", color: .green)
                CCHeaderStat(label: "ACTIVE NOW", value: vm.formatNumber(vm.activeNow), color: .yellow)
                CCHeaderStat(label: "REVENUE/DAY", value: "$\(vm.formatNumber(vm.revenueToday))", color: .green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.0, green: 0.05, blue: 0.1))
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
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                            }
                            if tab == .content && vm.contentFlags.contains(where: { !$0.reviewed }) {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                            }
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(selectedTab == tab ? .black : .secondary)
                        }
                        .frame(minWidth: 80)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? Color.cyan : Color(.systemGray6))
                    }
                }
            }
        }
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
                .fill(LinearGradient(
                    colors: vm.platformHealth >= 80
                        ? [Color.green.opacity(0.15), Color.green.opacity(0.05)]
                        : [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            VStack(spacing: 8) {
                HStack {
                    Text("PLATFORM HEALTH SCORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vm.platformHealth >= 80 ? "🟢 GOOD" : vm.platformHealth >= 60 ? "🟡 FAIR" : "🔴 NEEDS ATTENTION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(Int(vm.platformHealth))%")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(vm.platformHealth >= 80 ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Based on: uptime, fraud rate,")
                        Text("content safety, user growth,")
                        Text("revenue performance")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(vm.platformHealth >= 80 ? Color.green : Color.orange)
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
            CCMetricCard(title: "TOTAL DOWNLOADS", value: vm.formatNumber(vm.totalDownloads), subtitle: "+\(vm.formatNumber(vm.newDownloadsToday)) today", color: .cyan, icon: "arrow.down.circle.fill")
            CCMetricCard(title: "VIDEOS UPLOADED", value: vm.formatNumber(vm.videosUploaded), subtitle: "+\(vm.videosUploadedToday) today", color: .blue, icon: "video.circle.fill")
            CCMetricCard(title: "FRAUD BLOCKED", value: "\(vm.fraudAlerts.count)", subtitle: "\(vm.fraudAlerts.filter { !$0.reviewed }.count) unreviewed", color: vm.fraudAlerts.isEmpty ? .green : .red, icon: "shield.slash.fill")
            CCMetricCard(title: "CONTENT FLAGS", value: "\(vm.contentFlags.count)", subtitle: "\(vm.contentFlags.filter { !$0.reviewed }.count) pending", color: vm.contentFlags.isEmpty ? .green : .orange, icon: "exclamationmark.triangle.fill")
            CCMetricCard(title: "AVG SESSION", value: "\(vm.avgSessionMinutes)m", subtitle: "per active user", color: .purple, icon: "timer")
            CCMetricCard(title: "CREATOR COUNT", value: vm.formatNumber(vm.creatorCount), subtitle: "+\(vm.newCreatorsToday) today", color: .yellow, icon: "person.fill.checkmark")
            NavigationLink(destination: StrikeReviewView()) {
                CCMetricCard(title: "3-STRIKE QUEUE", value: "\(vm.strikeQueueCount)", subtitle: "\(vm.strikeQueueCount) awaiting your review", color: vm.strikeQueueCount > 0 ? .red : .green, icon: "bolt.fill")
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cyan)
                Text("AI DAILY BRIEFING")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(vm.summaryGeneratedAt, style: .time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text(vm.dailySummary)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
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
                .foregroundColor(.cyan)
            }
            .disabled(vm.isGeneratingBriefing)
        }
        .padding(14)
        .background(Color.cyan.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
    }

    private var departmentStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEPARTMENT STATUS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

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
                .foregroundColor(.secondary)
            ForEach(vm.recentEvents.prefix(8)) { event in
                PlatformEventRow(event: event)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - USERS TAB

    private var usersTab: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Total Users Banner
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.0, blue: 0.15), Color(red: 0.1, green: 0.0, blue: 0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 6) {
                        Text("TOTAL APP DOWNLOADS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple.opacity(0.8))
                        Text(vm.formatNumber(vm.totalDownloads))
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(.purple)
                        HStack(spacing: 16) {
                            VStack {
                                Text("+\(vm.formatNumber(vm.newDownloadsToday))")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.green)
                                Text("TODAY").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                            }
                            VStack {
                                Text("+\(vm.formatNumber(vm.newDownloadsWeek))")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.cyan)
                                Text("THIS WEEK").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                            }
                            VStack {
                                Text("+\(vm.formatNumber(vm.newDownloadsMonth))")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.yellow)
                                Text("THIS MONTH").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                }
                .cornerRadius(16)

                // User Breakdown
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    CCMetricCard(title: "REGISTERED USERS", value: vm.formatNumber(vm.totalUsers), subtitle: "accounts created", color: .blue, icon: "person.fill")
                    CCMetricCard(title: "ACTIVE TODAY", value: vm.formatNumber(vm.activeNow), subtitle: "currently in app", color: .green, icon: "eye.fill")
                    CCMetricCard(title: "CREATORS", value: vm.formatNumber(vm.creatorCount), subtitle: "uploading content", color: .orange, icon: "video.fill")
                    CCMetricCard(title: "PAID SUBSCRIBERS", value: vm.formatNumber(vm.paidUsers), subtitle: "premium members", color: .yellow, icon: "star.fill")
                    CCMetricCard(title: "DAY 1 RETENTION", value: "\(vm.day1Retention)%", subtitle: "come back next day", color: .cyan, icon: "return")
                    CCMetricCard(title: "DAY 7 RETENTION", value: "\(vm.day7Retention)%", subtitle: "weekly retention", color: .purple, icon: "calendar")
                }

                // Top Countries
                if !vm.topCountries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TOP COUNTRIES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        ForEach(vm.topCountries.prefix(5)) { country in
                            HStack {
                                Text(country.flag).font(.system(size: 20))
                                Text(country.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(vm.formatNumber(country.users) + " users")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("\(country.percent)%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
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
                        .foregroundColor(.secondary)
                    Text("\(vm.fraudAlerts.filter { !$0.reviewed }.count) ACTIVE ALERTS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(vm.fraudAlerts.contains(where: { !$0.reviewed }) ? .red : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BLOCKED TODAY")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                    Text("$\(vm.formatNumber(vm.fraudBlockedAmount))")
                        .font(.system(size: 16, weight: .black)).foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color(.systemGray6))

            if vm.fraudAlerts.isEmpty {
                Spacer()
                Image(systemName: "shield.checkered")
                    .font(.system(size: 56)).foregroundColor(.green.opacity(0.5))
                Text("ALL CLEAR").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.secondary)
                Text("No fraud detected").font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
                    Text("\(vm.contentFlags.filter { !$0.reviewed }.count) PENDING REVIEW")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(vm.contentFlags.contains(where: { !$0.reviewed }) ? .orange : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REMOVED TODAY")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                    Text("\(vm.contentRemovedToday)")
                        .font(.system(size: 16, weight: .black)).foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color(.systemGray6))

            if vm.contentFlags.isEmpty {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56)).foregroundColor(.green.opacity(0.5))
                Text("CLEAN PLATFORM").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.secondary)
                Text("No inappropriate content flagged").font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
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
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text.fill")
                        }
                        Text(vm.isGeneratingReport ? "GENERATING REPORT..." : "GENERATE TODAY'S REPORT")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(vm.isGeneratingReport ? Color.gray : Color.cyan)
                    .foregroundColor(.black).cornerRadius(12)
                }
                .disabled(vm.isGeneratingReport)

                // Reports List
                if vm.dailyReports.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.system(size: 48)).foregroundColor(.secondary.opacity(0.4))
                        Text("No reports yet").font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                        Text("Tap above to generate your first daily report").font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
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
            .foregroundColor(.cyan)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Color.cyan.opacity(0.08)).cornerRadius(8)
        }
    }
}

// MARK: - Supporting Views

private struct CCHeaderStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .black)).foregroundColor(color)
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CCMetricCard: View {
    let title: String; let value: String; let subtitle: String; let color: Color; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
            }
            Text(value).font(.system(size: 24, weight: .black)).foregroundColor(color)
            Text(subtitle).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08)).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

private struct DepartmentRow: View {
    let dept: Department
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(dept.statusColor).frame(width: 8, height: 8)
            Text(dept.name).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(dept.status).font(.system(size: 11, design: .monospaced)).foregroundColor(dept.statusColor)
            Text(dept.metric).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.systemGray6)).cornerRadius(8)
    }
}

private struct PlatformEventRow: View {
    let event: PlatformEvent
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: event.icon).font(.system(size: 12)).foregroundColor(event.color).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 12, weight: .semibold))
                Text(event.detail).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
            Text(event.timestamp, style: .relative).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(8).background(event.color.opacity(0.05)).cornerRadius(8)
    }
}

private struct FraudAlertRow: View {
    let alert: FraudAlert
    let onReview: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill").foregroundColor(.red)
                Text(alert.type.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.red)
                Spacer()
                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                if !alert.reviewed {
                    Text("NEW").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red).cornerRadius(4)
                }
            }
            Text(alert.description).font(.system(size: 12)).foregroundColor(.primary)
            HStack {
                Label(alert.amount, systemImage: "dollarsign.circle").font(.system(size: 11)).foregroundColor(.orange)
                Spacer()
                Text("User: \(alert.userId)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                if !alert.reviewed {
                    Button("MARK REVIEWED", action: onReview)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(alert.reviewed ? Color(.systemGray6) : Color.red.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(alert.reviewed ? Color.clear : Color.red.opacity(0.3), lineWidth: 1))
    }
}

private struct ContentFlagRow: View {
    let flag: ContentFlag
    let onApprove: () -> Void
    let onRemove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(flag.violationType.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.orange)
                Spacer()
                Text(flag.timestamp, style: .relative)
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                if !flag.reviewed {
                    Text("PENDING").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange).cornerRadius(4)
                }
            }
            Text("Video: \(flag.videoTitle)").font(.system(size: 13, weight: .semibold))
            Text("Creator: \(flag.creatorName)").font(.system(size: 11)).foregroundColor(.secondary)
            Text("AI Confidence: \(flag.confidence)%").font(.system(size: 11, design: .monospaced)).foregroundColor(.orange)
            if !flag.reviewed {
                HStack(spacing: 10) {
                    Button("✓ APPROVE", action: onApprove)
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.green)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.green.opacity(0.1)).cornerRadius(8)
                    Button("✕ REMOVE", action: onRemove)
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.red)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.red.opacity(0.1)).cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(flag.reviewed ? Color(.systemGray6) : Color.orange.opacity(0.07))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(flag.reviewed ? Color.clear : Color.orange.opacity(0.3), lineWidth: 1))
    }
}

private struct DailyReportCard: View {
    let report: DailyReport
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { expanded.toggle() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.date, style: .date)
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                        HStack(spacing: 12) {
                            scoreLabel("HEALTH", "\(Int(report.healthScore))%", report.healthScore >= 80 ? .green : .orange)
                            scoreLabel("USERS", "+\(report.newUsers)", .cyan)
                            scoreLabel("REVENUE", "$\(report.revenue)", .green)
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            if expanded {
                Divider()
                Text(report.summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary).lineSpacing(4)
                if !report.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIGHLIGHTS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                        ForEach(report.highlights, id: \.self) { h in
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(.yellow)
                                Text(h).font(.system(size: 12))
                            }
                        }
                    }
                }
                if !report.concerns.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONCERNS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                        ForEach(report.concerns, id: \.self) { c in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 8)).foregroundColor(.orange)
                                Text(c).font(.system(size: 12))
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6)).cornerRadius(12)
    }

    private func scoreLabel(_ title: String, _ val: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(val).font(.system(size: 12, weight: .bold)).foregroundColor(color)
            Text(title).font(.system(size: 8, design: .monospaced)).foregroundColor(.secondary)
        }
    }
}

// MARK: - Data Models

struct Department: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let metric: String
    let statusColor: Color
}

struct PlatformEvent: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let timestamp: Date
}

struct FraudAlert: Identifiable {
    let id: String
    let type: String
    let description: String
    let amount: String
    let userId: String
    let timestamp: Date
    var reviewed: Bool
}

struct ContentFlag: Identifiable {
    let id: String
    let videoTitle: String
    let creatorName: String
    let violationType: String
    let confidence: Int
    let timestamp: Date
    var reviewed: Bool
}

struct DailyReport: Identifiable {
    let id = UUID()
    let date: Date
    let healthScore: Double
    let newUsers: Int
    let revenue: String
    let summary: String
    let highlights: [String]
    let concerns: [String]
}

struct CountryStat: Identifiable {
    let id = UUID()
    let flag: String
    let name: String
    let users: Int
    let percent: Int
}

struct CreatorPulse: Identifiable {
    let id = UUID()
    let creatorName: String
    let status: String
    let viewsDelta: String
    let healthScore: Double
    let trendEmoji: String
    let isSpike: Bool
}

struct StrikeSnapshot: Identifiable {
    let id = UUID()
    let caseId: String
    let username: String
    let latestViolation: String
    let strikeCount: Int
    let aiRisk: Int
}

struct OwnerTask: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let createdAt: Date
}

// MARK: - ViewModel

@MainActor
class CommandCenterViewModel: ObservableObject {
    // User Stats
    @Published var totalUsers: Int = 0
    @Published var totalDownloads: Int = 0
    @Published var newUsersToday: Int = 0
    @Published var newDownloadsToday: Int = 0
    @Published var newDownloadsWeek: Int = 0
    @Published var newDownloadsMonth: Int = 0
    @Published var activeNow: Int = 0
    @Published var paidUsers: Int = 0
    @Published var creatorCount: Int = 0
    @Published var newCreatorsToday: Int = 0
    @Published var day1Retention: Int = 0
    @Published var day7Retention: Int = 0
    @Published var avgSessionMinutes: Int = 0
    @Published var topCountries: [CountryStat] = []

    // Revenue
    @Published var revenueToday: Int = 0

    // Platform Health
    @Published var platformHealth: Double = 92.0

    // Content
    @Published var videosUploaded: Int = 0
    @Published var videosUploadedToday: Int = 0
    @Published var contentFlags: [ContentFlag] = []
    @Published var contentRemovedToday: Int = 0

    // Fraud
    @Published var fraudAlerts: [FraudAlert] = []
    @Published var fraudBlockedAmount: Int = 0

    // Events & Departments
    @Published var recentEvents: [PlatformEvent] = []
    @Published var departments: [Department] = []

    // AI Briefing
    @Published var dailySummary: String = ""
    @Published var summaryGeneratedAt: Date = Date()
    @Published var isGeneratingBriefing = false

    // Reports
    @Published var dailyReports: [DailyReport] = []
    @Published var isGeneratingReport = false

    // 3-Strike Queue
    @Published var strikeQueueCount: Int = 0

    // Autopilot & creator health
    @Published var autopilotStatus: SelfHealingAIStatus = .placeholder
    @Published var creatorHealth: [CreatorPulse] = []
    @Published var strikeSnapshots: [StrikeSnapshot] = []
    @Published var ownerTasks: [OwnerTask] = []

    var hasOpenModerationItems: Bool {
        !openFraudAlerts.isEmpty || !openContentFlags.isEmpty
    }

    var openFraudAlerts: [FraudAlert] {
        fraudAlerts.filter { !$0.reviewed }
    }

    var openContentFlags: [ContentFlag] {
        contentFlags.filter { !$0.reviewed }
    }

    private var db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var refreshTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    
    // Owner UIDs for access control
    private let ownerUIDs = [
        "7EAoUc1aKsNRqR4cYBIOYVGB3Mf2"  // keontapeat@mychannel.live
    ]

    func startTracking() {
        loadFromFirestore()
        setupRealTimeListeners()
        setupDepartments()
        setupSampleEvents()
        // Auto-generate briefing on start
        Task { await generateDailyBriefing() }
        SelfHealingAIService.shared.startMonitoring()
        SelfHealingAIService.shared.$status
            .receive(on: RunLoop.main)
            .assign(to: &$autopilotStatus)
        setupOwnerTasks()
        setupCreatorHealth()
        setupStrikeSnapshots()
        // Refresh every 60 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadFromFirestore()
                self?.setupCreatorHealth()
                self?.setupStrikeSnapshots()
            }
        }
    }

    func stopTracking() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
        SelfHealingAIService.shared.stopMonitoring()
        cancellables.removeAll()
    }

    // MARK: - Firestore Loading

    func loadFromFirestore() {
        // Verify owner access
        guard let currentUser = Auth.auth().currentUser,
              ownerUIDs.contains(currentUser.uid) else {
            print("🚫 [CommandCenter] Access denied - not an owner")
            return
        }
        
        // Load analytics from dedicated analytics collection
        db.collection("platformAnalytics").document("daily").getDocument { [weak self] snap, _ in
            guard let self else { return }
            let data = snap?.data() ?? [:]
            Task { @MainActor in
                self.totalUsers = data["totalUsers"] as? Int ?? 0
                self.totalDownloads = data["totalDownloads"] as? Int ?? 0
                self.newUsersToday = data["newUsersToday"] as? Int ?? 0
                self.newDownloadsToday = data["newDownloadsToday"] as? Int ?? 0
                self.newDownloadsWeek = data["newDownloadsWeek"] as? Int ?? 0
                self.newDownloadsMonth = data["newDownloadsMonth"] as? Int ?? 0
                self.activeNow = data["activeNow"] as? Int ?? 0
                self.paidUsers = data["paidUsers"] as? Int ?? 0
                self.creatorCount = data["creatorCount"] as? Int ?? 0
                self.newCreatorsToday = data["newCreatorsToday"] as? Int ?? 0
                self.day1Retention = data["day1Retention"] as? Int ?? 0
                self.day7Retention = data["day7Retention"] as? Int ?? 0
                self.avgSessionMinutes = data["avgSessionMinutes"] as? Int ?? 0
                self.revenueToday = data["revenueToday"] as? Int ?? 0
                self.platformHealth = data["platformHealth"] as? Double ?? 92.0

                if let countriesData = data["topCountries"] as? [[String: Any]] {
                    self.topCountries = countriesData.compactMap { dict -> CountryStat? in
                        guard let name = dict["name"] as? String,
                              let flag = dict["flag"] as? String,
                              let users = dict["users"] as? Int,
                              let percent = dict["percent"] as? Int else { return nil }
                        return CountryStat(flag: flag, name: name, users: users, percent: percent)
                    }
                }
            }
        }

        // Load videos
        db.collection("videos").getDocuments { [weak self] snap, _ in
            guard let self else { return }
            let count = snap?.documents.count ?? 0
            Task { @MainActor in
                self.videosUploaded = count
                self.videosUploadedToday = max(0, count / 20)
            }
        }

        // Load fraud alerts from Firestore
        db.collection("fraudAlerts")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snap, _ in
                guard let self else { return }
                let alerts = snap?.documents.compactMap { doc -> FraudAlert? in
                    let data = doc.data()
                    guard let type = data["type"] as? String,
                          let desc = data["description"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return FraudAlert(
                        id: doc.documentID,
                        type: type,
                        description: desc,
                        amount: data["amount"] as? String ?? "$0",
                        userId: data["userId"] as? String ?? "unknown",
                        timestamp: ts,
                        reviewed: data["reviewed"] as? Bool ?? false
                    )
                } ?? []
                Task { @MainActor in
                    self.fraudAlerts = alerts
                    self.fraudBlockedAmount = alerts.reduce(0) { sum, a in
                        let val = Int(a.amount.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
                        return sum + val
                    }
                }
            }

        // Load content flags from Firestore
        db.collection("contentFlags")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snap, _ in
                guard let self else { return }
                let flags = snap?.documents.compactMap { doc -> ContentFlag? in
                    let data = doc.data()
                    guard let videoTitle = data["videoTitle"] as? String,
                          let violation = data["violationType"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return ContentFlag(
                        id: doc.documentID,
                        videoTitle: videoTitle,
                        creatorName: data["creatorName"] as? String ?? "Unknown Creator",
                        violationType: violation,
                        confidence: data["confidence"] as? Int ?? 90,
                        timestamp: ts,
                        reviewed: data["reviewed"] as? Bool ?? false
                    )
                } ?? []
                Task { @MainActor in
                    self.contentFlags = flags
                    self.contentRemovedToday = flags.filter { $0.reviewed }.count
                }
            }
    }

    // MARK: - Real-time Listeners

    func setupRealTimeListeners() {
        // Listen for new fraud alerts in real time
        let fraudListener = db.collection("fraudAlerts")
            .whereField("reviewed", isEqualTo: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let newAlerts = snap.documents.compactMap { doc -> FraudAlert? in
                    let data = doc.data()
                    guard let type = data["type"] as? String,
                          let desc = data["description"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return FraudAlert(
                        id: doc.documentID, type: type, description: desc,
                        amount: data["amount"] as? String ?? "$0",
                        userId: data["userId"] as? String ?? "unknown",
                        timestamp: ts, reviewed: false
                    )
                }
                Task { @MainActor in
                    // Merge with existing reviewed ones
                    let reviewed = self.fraudAlerts.filter { $0.reviewed }
                    self.fraudAlerts = (newAlerts + reviewed).sorted { $0.timestamp > $1.timestamp }
                }
            }
        listeners.append(fraudListener)

        // Listen for new content flags
        let contentListener = db.collection("contentFlags")
            .whereField("reviewed", isEqualTo: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap else { return }
                let newFlags = snap.documents.compactMap { doc -> ContentFlag? in
                    let data = doc.data()
                    guard let videoTitle = data["videoTitle"] as? String,
                          let violation = data["violationType"] as? String else { return nil }
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return ContentFlag(
                        id: doc.documentID, videoTitle: videoTitle,
                        creatorName: data["creatorName"] as? String ?? "Unknown",
                        violationType: violation, confidence: data["confidence"] as? Int ?? 90,
                        timestamp: ts, reviewed: false
                    )
                }
                Task { @MainActor in
                    let reviewed = self.contentFlags.filter { $0.reviewed }
                    self.contentFlags = (newFlags + reviewed).sorted { $0.timestamp > $1.timestamp }
                }
            }
        listeners.append(contentListener)

        // Listen for pending strike cases
        let strikeListener = db.collection("strikeCases")
            .whereField("status", isEqualTo: "pendingReview")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let count = snap?.documents.count ?? 0
                Task { @MainActor in self.strikeQueueCount = count }
            }
        listeners.append(strikeListener)
    }

    // MARK: - Actions

    func reviewFraudAlert(_ id: String) {
        db.collection("fraudAlerts").document(id).updateData(["reviewed": true])
        if let idx = fraudAlerts.firstIndex(where: { $0.id == id }) {
            fraudAlerts[idx].reviewed = true
        }
        setupStrikeSnapshots()
    }

    enum ContentAction { case approve, remove }

    func reviewContentFlag(_ id: String, action: ContentAction) {
        db.collection("contentFlags").document(id).updateData([
            "reviewed": true,
            "action": action == .approve ? "approved" : "removed"
        ])
        if let idx = contentFlags.firstIndex(where: { $0.id == id }) {
            contentFlags[idx].reviewed = true
        }
        if action == .remove { contentRemovedToday += 1 }
        setupStrikeSnapshots()
    }

    func addSampleTask() {
        let task = OwnerTask(
            title: "Call top creator",
            detail: "Give @NovaVision a surprise bonus for 3M views streak",
            createdAt: Date()
        )
        ownerTasks.append(task)
    }

    func completeTask(_ id: UUID) {
        ownerTasks.removeAll { $0.id == id }
    }

    func focusStrikeCase(id: String) {
        print("👁️ Opening strike case \(id)")
    }

    func refreshUserData() async {
        loadFromFirestore()
    }

    // MARK: - AI Briefing via Gemini

    func generateDailyBriefing() async {
        isGeneratingBriefing = true
        defer { isGeneratingBriefing = false }
        let prompt = """
        You are the Chief AI Officer for MyChannel, a next-gen video platform.
        Write a brief 3-paragraph executive daily briefing for the owner (Keonta).

        Platform Stats Today:
        - Total Users: \(formatNumber(totalUsers))
        - New Users Today: +\(formatNumber(newUsersToday))
        - Active Right Now: \(formatNumber(activeNow))
        - Videos Uploaded: \(formatNumber(videosUploaded))
        - Platform Health: \(Int(platformHealth))%
        - Fraud Alerts: \(fraudAlerts.count) (\(fraudAlerts.filter { !$0.reviewed }.count) unreviewed)
        - Content Flags: \(contentFlags.count) (\(contentFlags.filter { !$0.reviewed }.count) pending)
        - Revenue Today: $\(formatNumber(revenueToday))

        Write a concise, data-driven briefing covering:
        1. Overall platform performance today
        2. Key risks or issues to address
        3. One strategic recommendation

        Be direct, brief, and CEO-level. Use $ and % where relevant.
        """
        let key = AppSecrets.googleCloudAPIKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(key)") else {
            dailySummary = "Configure GOOGLE_CLOUD_API_KEY to enable AI briefings."
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]], "generationConfig": ["maxOutputTokens": 400]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                dailySummary = text.trimmingCharacters(in: .whitespacesAndNewlines)
                summaryGeneratedAt = Date()
            }
        } catch {
            dailySummary = "Briefing generation failed: \(error.localizedDescription)"
        }
    }

    func generateDailyReport() async {
        isGeneratingReport = true
        defer { isGeneratingReport = false }
        let prompt = """
        You are a data analyst for MyChannel. Generate a concise daily report for \(Date().formatted(date: .long, time: .omitted)).

        Stats:
        - Total Users: \(formatNumber(totalUsers)), New Today: +\(formatNumber(newUsersToday))
        - Revenue Today: $\(formatNumber(revenueToday))
        - Platform Health: \(Int(platformHealth))%
        - Videos Uploaded Total: \(formatNumber(videosUploaded)), Today: +\(videosUploadedToday)
        - Fraud Alerts: \(fraudAlerts.count), Content Flags: \(contentFlags.count)
        - Active Users: \(formatNumber(activeNow))

        Provide a report with:
        1. 2-3 sentence SUMMARY of today's performance
        2. 3 HIGHLIGHTS (good things)
        3. 2 CONCERNS (things to watch)

        Format exactly as:
        SUMMARY: [text]
        HIGHLIGHT: [text]
        HIGHLIGHT: [text]
        HIGHLIGHT: [text]
        CONCERN: [text]
        CONCERN: [text]
        """
        let key = AppSecrets.googleCloudAPIKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(key)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]], "generationConfig": ["maxOutputTokens": 500]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else { return }

            let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var summary = ""; var highlights: [String] = []; var concerns: [String] = []
            for line in lines {
                if line.hasPrefix("SUMMARY:") { summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
                else if line.hasPrefix("HIGHLIGHT:") { highlights.append(String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)) }
                else if line.hasPrefix("CONCERN:") { concerns.append(String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)) }
            }
            if summary.isEmpty { summary = text }
            let report = DailyReport(
                date: Date(), healthScore: platformHealth,
                newUsers: newUsersToday, revenue: formatNumber(revenueToday),
                summary: summary, highlights: highlights, concerns: concerns
            )
            dailyReports.insert(report, at: 0)
        } catch {}
    }

    // MARK: - Helpers

    private func setupDepartments() {
        let monitor = PlatformMonitorService.shared
        departments = [
            Department(name: "⚖️ 3-Strike Review", status: strikeQueueCount > 0 ? "NEEDS REVIEW" : "ALL CLEAR", metric: "\(strikeQueueCount) in queue", statusColor: strikeQueueCount > 0 ? .red : .green),
            Department(name: "🤖 AI Agent Army", status: AGIAgentManager.shared.isSchedulerRunning ? "RUNNING" : "STANDBY", metric: "\(AGIAgentManager.shared.agents.filter { $0.status == .live }.count)/30 LIVE", statusColor: AGIAgentManager.shared.isSchedulerRunning ? .green : .orange),
            Department(name: "🛡️ Fraud Detection", status: fraudAlerts.filter { !$0.reviewed }.isEmpty ? "ALL CLEAR" : "ALERT", metric: "\(monitor.fraudCaught) caught today", statusColor: fraudAlerts.filter { !$0.reviewed }.isEmpty ? .green : .red),
            Department(name: "📹 Content Moderation", status: contentFlags.filter { !$0.reviewed }.isEmpty ? "CLEAN" : "REVIEW", metric: "\(monitor.contentFlagged) flagged today", statusColor: contentFlags.filter { !$0.reviewed }.isEmpty ? .green : .orange),
            Department(name: "🔍 Platform Monitor", status: monitor.isRunning ? "SCANNING" : "OFFLINE", metric: "\(monitor.totalScansToday) scans today", statusColor: monitor.isRunning ? .cyan : .red),
            Department(name: "📈 Growth & Analytics", status: "TRACKING", metric: "+\(formatNumber(newUsersToday))/day", statusColor: .cyan),
            Department(name: "💰 Revenue", status: "EARNING", metric: "$\(formatNumber(revenueToday))/day", statusColor: .green),
            Department(name: "🎬 Creator Studio", status: "ACTIVE", metric: "\(formatNumber(creatorCount)) creators", statusColor: .yellow),
        ]
    }

    private func setupSampleEvents() {
        recentEvents = [
            PlatformEvent(title: "New user milestone", detail: "Platform reached \(formatNumber(totalUsers)) registered users", icon: "person.fill.checkmark", color: .green, timestamp: Date().addingTimeInterval(-300)),
            PlatformEvent(title: "AI Agents running", detail: "\(AGIAgentManager.shared.agents.filter { $0.isEnabled }.count) agents actively improving the platform", icon: "brain.head.profile", color: .cyan, timestamp: Date().addingTimeInterval(-900)),
            PlatformEvent(title: "Content uploaded", detail: "\(videosUploadedToday) new videos uploaded today", icon: "video.fill", color: .blue, timestamp: Date().addingTimeInterval(-1800)),
        ]
    }

    private func setupOwnerTasks() {
        let now = Date()
        let moderationDetail = openContentFlags.isEmpty
            ? "Keep moderation inbox below 10 pending items"
            : "\(openContentFlags.count) flagged videos awaiting decision"
        let fraudDetail = openFraudAlerts.isEmpty
            ? "Verify yesterday's transactions cleared AI review"
            : "\(openFraudAlerts.count) alerts require manual verification"
        let creatorDetail = creatorCount == 0
            ? "Spotlight 3 breakout creators from Stories"
            : "\(formatNumber(creatorCount)) creators live · send appreciation bonus"

        ownerTasks = [
            OwnerTask(
                title: "Clear strike queue",
                detail: strikeQueueCount > 0 ? "\(strikeQueueCount) cases waiting for review" : "Confirm queue is empty before EOD",
                createdAt: now.addingTimeInterval(-1200)
            ),
            OwnerTask(
                title: "Moderation sync",
                detail: moderationDetail,
                createdAt: now.addingTimeInterval(-3600)
            ),
            OwnerTask(
                title: "Fraud + payouts audit",
                detail: fraudDetail,
                createdAt: now.addingTimeInterval(-5400)
            ),
            OwnerTask(
                title: "Creator love",
                detail: creatorDetail,
                createdAt: now.addingTimeInterval(-7200)
            )
        ]
    }

    private func setupCreatorHealth() {
        let trendingViews = max(1_500, newUsersToday * 90)
        let retentionViews = max(900, day7Retention * 25)
        let monetizationViews = max(750, revenueToday / max(1, paidUsers == 0 ? 1 : paidUsers) * 20)

        creatorHealth = [
            CreatorPulse(
                creatorName: "NovaVision",
                status: "Stories streak · \(videosUploadedToday) uploads today",
                viewsDelta: "+\(formatNumber(trendingViews))",
                healthScore: min(100, platformHealth + 6),
                trendEmoji: "🔥",
                isSpike: true
            ),
            CreatorPulse(
                creatorName: "PulseWave",
                status: "Community tab driving \(day7Retention)% week retention",
                viewsDelta: "+\(formatNumber(retentionViews))",
                healthScore: max(48, platformHealth - 6),
                trendEmoji: "📈",
                isSpike: false
            ),
            CreatorPulse(
                creatorName: "Studio Atlas",
                status: "Live shopping beta pushing ARPU",
                viewsDelta: "+\(formatNumber(monetizationViews))",
                healthScore: min(100, platformHealth + 2),
                trendEmoji: "💎",
                isSpike: false
            )
        ]
    }

    private func setupStrikeSnapshots() {
        var snapshots: [StrikeSnapshot] = []

        let pendingFlags = contentFlags
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)

        for flag in pendingFlags {
            let strikeCount = max(1, min(3, flag.confidence / 35))
            let aiRisk = min(100, max(flag.confidence, strikeQueueCount * 10 + 30))
            snapshots.append(
                StrikeSnapshot(
                    caseId: flag.id,
                    username: flag.creatorName,
                    latestViolation: flag.violationType,
                    strikeCount: strikeCount,
                    aiRisk: aiRisk
                )
            )
        }

        if snapshots.count < 3 {
            let fraudCases = fraudAlerts
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(3 - snapshots.count)

            for alert in fraudCases {
                let digits = alert.amount.filter { $0.isNumber }
                let numericAmount = Int(digits) ?? 0
                let aiRisk = min(100, max(45, numericAmount / 400))
                snapshots.append(
                    StrikeSnapshot(
                        caseId: alert.id,
                        username: "User #\(alert.userId.prefix(6))",
                        latestViolation: alert.description,
                        strikeCount: 2,
                        aiRisk: aiRisk
                    )
                )
            }
        }

        if snapshots.isEmpty {
            snapshots = [
                StrikeSnapshot(
                    caseId: "AUTO-\(UUID().uuidString.prefix(6))",
                    username: "Compliance Monitor",
                    latestViolation: "System clean · no pending cases",
                    strikeCount: 0,
                    aiRisk: 5
                )
            ]
        }

        strikeSnapshots = snapshots
    }

    private func buildCountries(totalUsers: Int) -> [CountryStat] {
        let base = max(1, totalUsers)
        return [
            CountryStat(flag: "🇺🇸", name: "United States", users: Int(Double(base) * 0.38), percent: 38),
            CountryStat(flag: "🇬🇧", name: "United Kingdom", users: Int(Double(base) * 0.12), percent: 12),
            CountryStat(flag: "🇨🇦", name: "Canada", users: Int(Double(base) * 0.09), percent: 9),
            CountryStat(flag: "🇦🇺", name: "Australia", users: Int(Double(base) * 0.07), percent: 7),
            CountryStat(flag: "🇳🇬", name: "Nigeria", users: Int(Double(base) * 0.06), percent: 6),
        ]
    }

    func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
