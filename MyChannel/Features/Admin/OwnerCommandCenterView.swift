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


// ⚡ Supporting views + ViewModel extracted to CommandCenterViews.swift
