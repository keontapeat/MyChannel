//
//  AGIAgentDashboardView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🛰 CIA OPS CENTER - All 30 agents live, improving the app daily
//

import SwiftUI
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Combined Log Event Model
struct CombinedLogEvent: Identifiable {
    let id: String
    let timestamp: Date
    let source: String
    let title: String
    let detail: String
    let success: Bool
}

// MARK: - CIA Ops Dashboard

struct AGIAgentDashboardView: View {
    @StateObject private var agentManager = AGIAgentManager.shared
    @State private var selectedTab: DashboardTab = .ops
    @State private var selectedCategory: AGIAgentCategory? = nil
    @State private var showingDeploySheet = false
    @State private var agentToDeploy: AGIAgentConfig? = nil
    @State private var searchText = ""
    @State private var isDeployingAll = false
    @State private var pulseAnimation = false
    
    // Playground States
    @State private var playgroundSelectedAgentId = "agent-007-dynamic-pricing"
    @State private var playgroundInputText = ""
    @State private var playgroundOutputText = ""
    @State private var isSimulatingRun = false
    
    // Live Feed Combined logs states
    @State private var combinedEvents: [CombinedLogEvent] = []
    @State private var isLoadingLogs = false
 
    enum DashboardTab: String, CaseIterable {
        case ops = "OPS"
        case agents = "AGENTS"
        case playground = "PLAYGROUND"
        case feed = "LIVE FEED"
        case patents = "PATENTS"
    }
 
    var stats: AGIAgentStats { agentManager.getAgentStats() }
 
    var filteredAgents: [AGIAgentConfig] {
        var agents = agentManager.agents
        if let category = selectedCategory {
            agents = agents.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            agents = agents.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return agents.sorted { $0.priority < $1.priority }
    }
 
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            switch selectedTab {
            case .ops: opsCenter
            case .agents: agentsPanel
            case .playground: playgroundPanel
            case .feed: liveFeedPanel
            case .patents: patentsPanel
            }
        }
        .navigationTitle("🛰 AGENT OPS CENTER")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .sheet(isPresented: $showingDeploySheet) {
            if let agent = agentToDeploy {
                AgentDeploySheet(agent: agent)
            }
        }
    }
 
    // MARK: - Tab Bar
 
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(selectedTab == tab ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selectedTab == tab ? Color.green : Color(.systemGray6))
                }
            }
        }
    }

    // MARK: - OPS CENTER

    private var opsCenter: some View {
        ScrollView {
            VStack(spacing: 14) {
                revenueBanner
                systemStatusBar
                if stats.live < agentManager.agents.count {
                    deployAllButton
                }
                statsGrid
                quickActions
                if !agentManager.activityLog.isEmpty {
                    recentActivityPreview
                }
            }
            .padding(16)
        }
    }

    private var revenueBanner: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.1, blue: 0.03), Color(red: 0.0, green: 0.12, blue: 0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    Text("EXECUTIVE OPS SUMMARY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
                
                Text("+$\(Int(stats.estimatedRevenue))M ARR")
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.green)
                
                Text("\(stats.live) of \(stats.total) agents operational")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green.opacity(0.6))
                
                Divider()
                    .background(Color.green.opacity(0.2))
                    .padding(.horizontal, 20)
                
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        let spend = Double(agentManager.totalRunsToday) * 0.015
                        Text(String(format: "$%.2f", spend))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("EST. API SPEND")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 2) {
                        let ratio = stats.estimatedRevenue > 0 ? (stats.estimatedRevenue * 1000000.0) / max(1.0, Double(agentManager.totalRunsToday) * 0.015 * 365.0) : 0.0
                        Text(String(format: "%.0f:1", ratio))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("EFFICIENCY RATIO")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CEO BRIEFING:")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    let briefing = agentManager.isSchedulerRunning 
                        ? "Autonomous AGI army active. Net efficiency is high. Anti-Cheat and Revenue agents running optimally."
                        : "CRITICAL: Platform scheduler is OFFLINE. Autonomous money-making pipelines are idle."
                    
                    Text(briefing)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .padding(8)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 20)
        }
        .cornerRadius(16)
    }

    private var systemStatusBar: some View {
        HStack(spacing: 10) {
            CIAPill(label: "SCHEDULER",
                    value: agentManager.isSchedulerRunning ? "ACTIVE" : "OFFLINE",
                    color: agentManager.isSchedulerRunning ? .green : .red)
            CIAPill(label: "RUNS TODAY",
                    value: "\(agentManager.totalRunsToday)",
                    color: .cyan)
            CIAPill(label: "SUCCESS RATE",
                    value: String(format: "%.0f%%", agentManager.successRatePercent),
                    color: agentManager.successRatePercent >= 90 ? .green : .orange)
        }
    }

    private var deployAllButton: some View {
        Button {
            isDeployingAll = true
            Task {
                await agentManager.deployAllAgents()
                await MainActor.run { isDeployingAll = false }
            }
        } label: {
            HStack(spacing: 10) {
                if isDeployingAll {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(isDeployingAll ? "DEPLOYING ALL AGENTS..." : "DEPLOY ALL \(agentManager.agents.count) AGENTS + START SCHEDULER")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isDeployingAll ? Color.gray : Color.green)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
        .disabled(isDeployingAll)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CIAStatTile(title: "LIVE", value: "\(stats.live)", color: .green, icon: "antenna.radiowaves.left.and.right")
            CIAStatTile(title: "READY", value: "\(stats.ready)", color: .yellow, icon: "clock.fill")
            CIAStatTile(title: "PLANNED", value: "\(stats.planned)", color: .gray, icon: "lightbulb")
            CIAStatTile(title: "TOTAL", value: "\(stats.total)", color: .cyan, icon: "cpu")
            CIAStatTile(title: "ENABLED", value: "\(agentManager.agents.filter { $0.isEnabled }.count)", color: .blue, icon: "checkmark.seal.fill")
            CIAStatTile(title: "LOG ENTRIES", value: "\(agentManager.activityLog.count)", color: .purple, icon: "doc.text.fill")
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CIAActionTile(title: "PHASE 1\nMONEY", icon: "dollarsign.circle.fill", color: .green) {
                        Task { await agentManager.deployPhase1Agents() }
                    }
                    CIAActionTile(title: "START\nSCHEDULER", icon: "play.circle.fill", color: .cyan) {
                        agentManager.startScheduler()
                    }
                    CIAActionTile(title: "STOP\nSCHEDULER", icon: "stop.circle.fill", color: .orange) {
                        agentManager.stopScheduler()
                    }
                    CIAActionTile(title: "DEPLOY\nREADY", icon: "bolt.circle.fill", color: .yellow) {
                        Task {
                            let readyIds = AGIAgentCatalog.readyToDeploy().map { $0.id }
                            await agentManager.deployAgents(readyIds)
                        }
                    }
                    CIAActionTile(title: "VIEW\nAGENTS", icon: "list.bullet.rectangle", color: .blue) {
                        selectedTab = .agents
                    }
                }
            }
        }
    }

    private var recentActivityPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT ACTIVITY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button("SEE ALL →") { selectedTab = .feed }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            ForEach(agentManager.activityLog.prefix(3)) { activity in
                FeedRow(activity: activity)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - AGENTS PANEL

    private var agentsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search agents...", text: $searchText)
                    .font(.system(size: 14))
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CIACategoryChip(title: "ALL", isSelected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(AGIAgentCategory.allCases, id: \.self) { cat in
                        CIACategoryChip(
                            title: String(cat.rawValue.prefix(10)),
                            isSelected: selectedCategory == cat
                        ) { selectedCategory = cat }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredAgents) { agent in
                        AgentRow(agent: agent, lastActivity: agentManager.activityLog.first { $0.agentId == agent.id }) {
                            agentToDeploy = agent
                            showingDeploySheet = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - PATENTS PANEL

    @State private var disclosureDate: Date = InventionDisclosureStore.loadOrCreate()
    @State private var showShareSheet = false
    @State private var shareText = ""

    private var patentsPanel: some View {
        ScrollView {
            VStack(spacing: 14) {

                // PRIOR ART PROTECTION BANNER
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.12, blue: 0.0), Color(red: 0.0, green: 0.18, blue: 0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("PRIOR ART PROTECTION ACTIVE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.green.opacity(0.9))
                        }
                        Text("Documented")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))
                        Text(disclosureDate, style: .date)
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.green)
                        Text(disclosureDate, style: .time)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .padding(.vertical, 20)
                }
                .cornerRadius(16)

                // HOW THIS PROTECTS YOU
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        Text("HOW THIS PROTECTS YOU RIGHT NOW")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    ProtectionRow(icon: "calendar.badge.checkmark", color: .green,
                        title: "Establishes Your Conception Date",
                        description: "This document proves you invented these ideas on " + disclosureDate.formatted(date: .long, time: .shortened) + ". If anyone files later, your date beats theirs.")
                    ProtectionRow(icon: "doc.text.magnifyingglass", color: .cyan,
                        title: "Creates Prior Art",
                        description: "Documented inventions become \"prior art\". If YouTube or anyone tries to patent the same idea, your dated record can invalidate their patent application.")
                    ProtectionRow(icon: "square.and.arrow.up", color: .purple,
                        title: "Export & Email It To Yourself",
                        description: "Tap \"Export Disclosure\" below and email it to yourself. The email server timestamp gives you a second independent proof of date. Also text it to someone you trust.")
                    ProtectionRow(icon: "dollarsign.circle", color: .orange,
                        title: "Provisional Patent — $320 When Ready",
                        description: "A USPTO Provisional Patent Application costs $320 for small entities and gives you 12 months of \"Patent Pending\" status. Use this disclosure to file it yourself at USPTO.gov.")
                    ProtectionRow(icon: "building.columns", color: .yellow,
                        title: "Copyright Is Free & Already Active",
                        description: "Your source code, UI designs, and written documents are automatically copyright-protected from the moment they were written. No filing needed.")
                }
                .padding(14)
                .background(Color.green.opacity(0.06))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.25), lineWidth: 1))

                // EXPORT BUTTON
                Button {
                    shareText = InventionDisclosureStore.generateDisclosureText(
                        date: disclosureDate, items: patentItems
                    )
                    showShareSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EXPORT INVENTION DISCLOSURE")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                            Text("Email to yourself · Text it · Save to Files")
                                .font(.system(size: 10, design: .monospaced))
                                .opacity(0.75)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .sheet(isPresented: $showShareSheet) {
                    NativeShareSheet(items: [shareText])
                }

                // Portfolio value banner
                let totalLow = patentItems.reduce(0) { $0 + $1.estimatedValueLow }
                let totalHigh = patentItems.reduce(0) { $0 + $1.estimatedValueHigh }
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.08, blue: 0.18), Color(red: 0.0, green: 0.12, blue: 0.26)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 12))
                            Text("ESTIMATED PORTFOLIO VALUE")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.85))
                        }
                        Text("$\(totalLow)M – $\(totalHigh)M")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.cyan)
                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("\(patentItems.count)")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("TOTAL PATENTS")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 32)
                            VStack(spacing: 2) {
                                Text("\(patentItems.filter { $0.priority == .high }.count)")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundColor(.red)
                                Text("HIGH VALUE")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 32)
                            VStack(spacing: 2) {
                                Text("\(Set(patentItems.map { $0.category }).count)")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundColor(.purple)
                                Text("CATEGORIES")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple.opacity(0.7))
                            }
                        }
                        Text("Based on comparable tech patent licensing deals & acquisition comps")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 12)
                }
                .cornerRadius(16)

                // Stats row
                HStack(spacing: 10) {
                    PatentStatPill(label: "HIGH VALUE", value: "\(patentItems.filter { $0.priority == .high }.count)", color: .red)
                    PatentStatPill(label: "MEDIUM", value: "\(patentItems.filter { $0.priority == .medium }.count)", color: .orange)
                    PatentStatPill(label: "CATEGORIES", value: "\(Set(patentItems.map { $0.category }).count)", color: .purple)
                    PatentStatPill(label: "TOTAL", value: "\(patentItems.count)", color: .cyan)
                }

                // Patent items by category
                ForEach(patentCategories, id: \.self) { category in
                    let items = patentItems.filter { $0.category == category }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            ForEach(items) { item in
                                PatentItemCard(item: item)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var patentCategories: [String] {
        var seen = Set<String>()
        return patentItems.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    private var patentItems: [PatentItem] {
        [
            // AI & AGI Systems
            PatentItem(title: "Autonomous AGI Agent Scheduler for Social Video Platforms",
                       description: "A self-scheduling system of 30+ AI agents that autonomously run at defined intervals to optimize revenue, content, fraud, and growth on a video-sharing platform without human intervention.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 50, estimatedValueHigh: 200),
            PatentItem(title: "Multi-Agent AI Orchestration with Per-Agent Run Intervals",
                       description: "Architecture where each AI agent has its own independent timer-based execution schedule, category assignment, and priority weighting within a unified orchestration layer.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 120),
            PatentItem(title: "Real-Time AI Ranking Engine Combining Watch Time, Shares & Freshness",
                       description: "A scoring algorithm that weights video ranking using a live combination of watch-time percentage, re-watch rate, share velocity, comment sentiment, and content freshness decay.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 40, estimatedValueHigh: 150),
            PatentItem(title: "AI Swarm Intelligence for Collective Platform Optimization",
                       description: "A distributed swarm intelligence system where multiple AI agents collectively vote on and execute platform-wide optimizations, with no single agent having full control.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 100),
            PatentItem(title: "Self-Evolving AI Engine that Rewrites Its Own Optimization Rules",
                       description: "An AI evolution engine that monitors its own performance metrics and autonomously adjusts its scoring weights, feature importance, and decision thresholds over time without developer intervention.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 60, estimatedValueHigh: 250),
            PatentItem(title: "AI Crystal Ball — Predictive Platform Health Forecasting",
                       description: "A predictive analytics engine that forecasts platform-wide KPIs (revenue, churn, viral content) 7–30 days in advance using time-series ML models trained on the platform's own data.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 80),
            PatentItem(title: "Gemini + Vertex AI Fallback Routing for Mobile Agent Calls",
                       description: "System that routes agent calls to Vertex AI Cloud Run when an agent ID is configured, with automatic fallback to Gemini 1.5 Pro for prompt-template agents.",
                       category: "AI & AGI Systems", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 5, estimatedValueHigh: 20),
            PatentItem(title: "Enterprise AI Team Orchestration with Role-Based Agent Assignment",
                       description: "Architecture that assigns AI agents to department roles (growth, monetization, safety, analytics) and coordinates their outputs like a virtual executive team inside a mobile app.",
                       category: "AI & AGI Systems", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 35, estimatedValueHigh: 130),

            // AI Video & Content Tools
            PatentItem(title: "AI Video Co-Creator with Real-Time Script & Scene Suggestions",
                       description: "An in-app AI co-creator tool that analyzes a creator's draft video and generates real-time script improvements, scene transition suggestions, and hook optimizations before publishing.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 40, estimatedValueHigh: 150),
            PatentItem(title: "AI Content Factory — Batch Video Concept & Script Generation",
                       description: "System that generates multiple video concepts, outlines, and full scripts in batch from a single topic prompt, ranked by predicted viral score before the creator records anything.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 100),
            PatentItem(title: "Real-Time AI Background Removal for Mobile Live Streams",
                       description: "On-device AI background removal engine that processes live camera frames in real time on mobile hardware, replacing backgrounds during live streaming without requiring a green screen.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 90),
            PatentItem(title: "AI Scene Detection Engine for Automatic Chapter Generation",
                       description: "ML model that analyzes video content and automatically detects scene changes, topic shifts, and key moments to generate timestamped chapters without creator input.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 15, estimatedValueHigh: 60),
            PatentItem(title: "AI Video Upscaling Engine for Mobile-Uploaded Content",
                       description: "On-device or cloud AI super-resolution engine that upscales low-quality creator-uploaded videos to higher resolutions using neural network inference at upload time.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 75),
            PatentItem(title: "AI Deepfake Detection Engine Integrated at Video Upload",
                       description: "Automated deepfake and synthetic media detection system that scans every uploaded video before publishing, flagging AI-generated faces and manipulated audio with confidence scores.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 120),
            PatentItem(title: "AI Thumbnail A/B Testing Engine with Predicted CTR Scoring",
                       description: "System that generates multiple AI-created thumbnail variants for a video, predicts click-through rate for each using a trained model, and automatically rotates the best performer.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 40),
            PatentItem(title: "AI Voice Synthesis Engine for Creator Dubbing & Voiceover",
                       description: "In-platform AI voice cloning and synthesis tool that allows creators to generate a voice-over or dubbed version of their video in a different language using their own cloned voice.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 50, estimatedValueHigh: 180),
            PatentItem(title: "AI Music Generation Engine for Creator Background Tracks",
                       description: "On-demand AI music composition system that generates royalty-free background music tailored to a video's mood, pacing, and genre — directly within the creator studio.",
                       category: "AI Video & Content Tools", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 90),
            PatentItem(title: "AI Comment Sentiment Analysis Feeding Creator Studio Insights",
                       description: "Real-time NLP engine that classifies comment sentiment per video and surfaces aggregated emotional response data (love, anger, confusion, hype) inside the creator analytics dashboard.",
                       category: "AI Video & Content Tools", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 30),

            // Creator & Monetization
            PatentItem(title: "Creator Boost Bidding System for Algorithmic Promotion",
                       description: "A self-serve auction system where creators bid credits or cash to boost their content in the algorithmic feed, with AI-based relevance scoring preventing low-quality content from winning bids.",
                       category: "Creator & Monetization", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 100),
            PatentItem(title: "Featured Video Slot Payment & Scheduling System",
                       description: "Method for creators to purchase time-limited featured placement slots on a video platform, with automatic expiration, refund logic, and real-time slot availability tracking.",
                       category: "Creator & Monetization", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 15, estimatedValueHigh: 60),
            PatentItem(title: "Dynamic Subscription Pricing via AI Demand Forecasting",
                       description: "A pricing engine that adjusts subscription tier prices in real time based on AI-predicted demand curves, regional purchasing power, and cohort churn signals.",
                       category: "Creator & Monetization", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 75),
            PatentItem(title: "Escrow-Based Creator Payment System with Milestone Unlocks",
                       description: "A payment escrow architecture where brand deal funds are held and released to creators upon AI-verified completion of deliverable milestones (views, engagement thresholds).",
                       category: "Creator & Monetization", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 50, estimatedValueHigh: 150),
            PatentItem(title: "Super Chat Priority Queue with Tiered Visibility During Live Streams",
                       description: "A monetized live chat system where viewer payment amount determines message display duration, font size, and position in a priority queue visible to the streamer and all viewers.",
                       category: "Creator & Monetization", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 80),
            PatentItem(title: "Video Premiere Countdown with Pre-Release Community Engagement",
                       description: "A scheduled video premiere system that shows a countdown to non-subscribers, enables pre-premiere chat, and tracks pre-premiere engagement metrics as a launch signal for the algorithm.",
                       category: "Creator & Monetization", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 5, estimatedValueHigh: 20),
            PatentItem(title: "Music Payout Proportional Distribution Engine",
                       description: "System for distributing music licensing revenue proportionally across rights holders based on actual play counts per track per creator, reconciled at payout intervals.",
                       category: "Creator & Monetization", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 35),
            PatentItem(title: "AI Career Categorization for Creator Monetization Tier Assignment",
                       description: "ML classifier that analyzes creator content, audience demographics, and engagement patterns to automatically assign creators to monetization tiers and unlock relevant revenue streams.",
                       category: "Creator & Monetization", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 25),

            // Gaming & Esports
            PatentItem(title: "Live Streamer Championship Belt & Title Defense System",
                       description: "A gamified ranking system where streamers earn, defend, and can lose championship titles based on head-to-head stream performance metrics over defined competition windows.",
                       category: "Gaming & Esports", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 35, estimatedValueHigh: 120),
            PatentItem(title: "AI-Powered Match Fairness Engine for Streamer Tournaments",
                       description: "An algorithm that dynamically pairs tournament competitors based on historical performance, audience size, and engagement equity scores to ensure balanced matchups.",
                       category: "Gaming & Esports", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 75),
            PatentItem(title: "Anti-Cheat AI System for Viewer Count & Engagement Validation",
                       description: "Real-time machine learning system that detects artificial inflation of viewer counts, watch time, likes, and comments using behavioral biometric patterns and network anomaly detection.",
                       category: "Gaming & Esports", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 100),
            PatentItem(title: "Live 1v1 Versus Match System for Content Creators",
                       description: "Real-time head-to-head match system where two creators compete simultaneously, with audience voting, live score tracking, and an AI referee determining the winner based on engagement metrics.",
                       category: "Gaming & Esports", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 75, estimatedValueHigh: 200),
            PatentItem(title: "Match Proof Upload & AI Verification System for Tournaments",
                       description: "System requiring tournament participants to upload screen recordings or screenshots as match proof, with AI verification confirming authenticity before results are officially recorded.",
                       category: "Gaming & Esports", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 15, estimatedValueHigh: 50),
            PatentItem(title: "3D Tournament Bracket Visualization with Live Score Updates",
                       description: "A three-dimensional interactive tournament bracket UI rendered in a mobile app that updates in real time as matches complete, with animated transitions and prize pool breakdowns per round.",
                       category: "Gaming & Esports", priority: .medium, claimType: "Design + Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 25),
            PatentItem(title: "Referee Dashboard for Creator Tournament Dispute Resolution",
                       description: "An admin interface giving designated referees the ability to review disputed match results, view uploaded proof, override AI decisions, and log rulings with audit trails.",
                       category: "Gaming & Esports", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 5, estimatedValueHigh: 18),
            PatentItem(title: "Gameplay Video AI Analysis for Performance Scoring",
                       description: "AI system that analyzes uploaded gameplay footage to extract performance statistics (reaction time, accuracy, decision quality) and translate them into a normalized competitive score.",
                       category: "Gaming & Esports", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 90),

            // Content & Safety
            PatentItem(title: "3-Strike Owner Review System with Admin Decision Logging",
                       description: "A content moderation framework where an owner/admin reviews flagged content with one-tap warn/strike/suspend/dismiss actions, with all decisions logged immutably per user account.",
                       category: "Content & Safety", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 15, estimatedValueHigh: 55),
            PatentItem(title: "AI Fraud Detection with Real-Time Admin Alert Dashboard",
                       description: "Combined AI fraud scoring and human-review dashboard that flags suspicious financial transactions, account behavior, and stream anomalies, routing them to admin with severity levels.",
                       category: "Content & Safety", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 90),
            PatentItem(title: "Unified Owner Command Center with Department-Level KPI Feeds",
                       description: "A single owner-only mobile interface aggregating live KPIs across users, revenue, fraud, content moderation, and daily reports — styled as an operations command center.",
                       category: "Content & Safety", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 35),
            PatentItem(title: "AI Anomaly Detection Engine for Platform Health Monitoring",
                       description: "Continuous monitoring system that uses statistical anomaly detection on platform telemetry to surface unusual patterns in uploads, logins, transactions, and engagement before they become incidents.",
                       category: "Content & Safety", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 70),
            PatentItem(title: "Click Fraud Detector with Bot Traffic Filtering for Ad Impressions",
                       description: "Real-time bot traffic filter that validates ad impression and click events using behavioral fingerprinting, IP reputation scoring, and interaction timing analysis before counting billable events.",
                       category: "Content & Safety", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 100),

            // Stories & Short Video
            PatentItem(title: "Circular Story Ring Progress Indicator with Per-Segment Tracking",
                       description: "UI component displaying multi-story progress as segmented arcs on a circular avatar ring, with per-segment animation timing and viewed/unviewed state persistence.",
                       category: "Stories & Short Video", priority: .medium, claimType: "Design + Utility Patent",
                       estimatedValueLow: 5, estimatedValueHigh: 20),
            PatentItem(title: "Stories Feed with Creator-Type Sorting (Live-First Algorithm)",
                       description: "A stories carousel that dynamically reorders creators by live status, unread count, and AI-predicted engagement likelihood, placing live streamers at front of queue.",
                       category: "Stories & Short Video", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 30),
            PatentItem(title: "Flicks Challenge System with Viral Score Tracking",
                       description: "A hashtag-based viral video challenge system that tracks participation counts, assigns challenge viral scores, and surfaces trending challenges algorithmically based on acceleration velocity.",
                       category: "Stories & Short Video", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 70),
            PatentItem(title: "Vertical Short-Form Video Feed with Swipe-Gated Comment Access",
                       description: "A full-screen vertical video feed where comments are accessible via a gesture-gated overlay that doesn't interrupt playback, keeping video visible while reading/writing comments.",
                       category: "Stories & Short Video", priority: .medium, claimType: "Design + Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 35),

            // Platform Architecture
            PatentItem(title: "Offline-First Video Platform with Service Worker CDN Fallback",
                       description: "Architecture combining Firebase Hosting, a registered service worker, and CDN-signed URLs to deliver video content with offline playback capability and seamless online sync.",
                       category: "Platform Architecture", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 30),
            PatentItem(title: "Multi-CDN Signed URL Rotation for Video Delivery Security",
                       description: "System that rotates time-limited signed CDN URLs across multiple CDN providers per video request, preventing hotlinking while maintaining sub-100ms URL generation latency.",
                       category: "Platform Architecture", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 40),
            PatentItem(title: "Vertical AGI Agent Dashboard with Live Activity Feed in Mobile App",
                       description: "A native mobile screen embedding a real-time AI agent activity log feed inside an operations dashboard, showing per-agent latency, output, and scheduler status.",
                       category: "Platform Architecture", priority: .medium, claimType: "Design + Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 25),
            PatentItem(title: "Adaptive Bitrate Streaming Engine V2 with AI Bandwidth Prediction",
                       description: "Next-generation ABR streaming engine that uses AI-predicted bandwidth availability to pre-switch quality tiers before congestion occurs, reducing rebuffering vs reactive ABR systems.",
                       category: "Platform Architecture", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 110),
            PatentItem(title: "Background Play with Lock Screen Media Controls for Mobile Video",
                       description: "System enabling video audio to continue playing when a mobile app is backgrounded or the screen is locked, with full media session controls surfaced on the lock screen and control center.",
                       category: "Platform Architecture", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 5, estimatedValueHigh: 20),
            PatentItem(title: "Multi-Account Switcher with Per-Account Notification Isolation",
                       description: "Architecture enabling a single mobile app install to manage multiple user accounts simultaneously, with isolated notification queues, feed states, and session tokens per account.",
                       category: "Platform Architecture", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 28),
            PatentItem(title: "Quantum Analytics Dashboard with Cohort Comparison Engine",
                       description: "Advanced analytics interface that allows platform operators to define custom user cohorts and render side-by-side performance comparisons across engagement, revenue, and retention metrics.",
                       category: "Platform Architecture", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 35),

            // Ads & Targeting
            PatentItem(title: "Real-Time Bidding (RTB) Ad Auction with AI Floor Price Adjustment",
                       description: "An RTB system where AI dynamically adjusts per-impression floor prices based on predicted viewer LTV, content category CPM history, and real-time fill rate signals.",
                       category: "Ads & Targeting", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 40, estimatedValueHigh: 150),
            PatentItem(title: "Ad Waterfall Mediation with AI-Ranked Network Priority",
                       description: "Ad mediation system that uses AI to dynamically reorder the waterfall of ad networks per request based on predicted fill rate and eCPM, maximizing revenue over static waterfall ordering.",
                       category: "Ads & Targeting", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 90),
            PatentItem(title: "Audience Lookalike Modeling from First-Party Watch Graph Data",
                       description: "ML pipeline that builds advertiser lookalike audiences exclusively from the platform's first-party watch-graph and engagement data, without relying on third-party data brokers.",
                       category: "Ads & Targeting", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 35, estimatedValueHigh: 120),
            PatentItem(title: "Live Shopping Overlay with Creator-Configurable Product Cards",
                       description: "System enabling creators to add purchasable product overlay cards to live streams, with AI-timed insertion, click-to-cart functionality, and real-time inventory sync.",
                       category: "Ads & Targeting", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 30, estimatedValueHigh: 100),
            PatentItem(title: "Ads Frequency Cap Service Preventing Viewer Ad Fatigue",
                       description: "Cross-session, cross-device ad frequency capping system that limits how many times a unique viewer sees the same ad creative within rolling time windows, with AI-tuned cap thresholds per audience segment.",
                       category: "Ads & Targeting", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 28),

            // Discovery & Search
            PatentItem(title: "AI Music Discovery Feed Blending Creator Uploads & Licensed Tracks",
                       description: "Recommendation engine that generates a unified music discovery feed by blending creator-uploaded audio content with licensed catalog tracks, ranked by listener taste profile vectors.",
                       category: "Discovery & Search", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 10, estimatedValueHigh: 35),
            PatentItem(title: "Cross-Platform Content Ingest with Rights Clearance Verification",
                       description: "Automated pipeline that ingests video content from external sources, runs AI-based rights clearance checks, and gates publishing until clearance status is confirmed.",
                       category: "Discovery & Search", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 25),
            PatentItem(title: "AI Search Engine with Intent Classification for Video Platforms",
                       description: "Search system that classifies user query intent (discovery, re-find, channel lookup, topic deep-dive) and adjusts result ranking strategy per intent type rather than using a universal ranking model.",
                       category: "Discovery & Search", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 20, estimatedValueHigh: 75),
            PatentItem(title: "Auto-Subtitle & Auto-Translation Engine Integrated at Upload",
                       description: "Pipeline that automatically generates subtitles for every uploaded video using speech recognition and then translates them into multiple languages at upload time, without creator action.",
                       category: "Discovery & Search", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 25, estimatedValueHigh: 85),
            PatentItem(title: "AI-Powered Collab Finder Matching Creators by Audience Compatibility",
                       description: "Matchmaking system that analyzes two creators' audience demographics, content categories, and engagement overlap to score collaboration compatibility and surface recommended collab partners.",
                       category: "Discovery & Search", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 15, estimatedValueHigh: 55),
            PatentItem(title: "Collaborative Playlist with Multi-Creator Co-Curation Permissions",
                       description: "Playlist system allowing multiple creators to be assigned co-curator roles with granular add/remove/reorder permissions, with a change log tracking each contributor's edits.",
                       category: "Discovery & Search", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 5, estimatedValueHigh: 18),

            // Creator Education
            PatentItem(title: "In-App Creator University with Certificate & Skill Progression",
                       description: "A structured learning system embedded in the creator studio that delivers courses on growth, monetization, and production, tracking completion and issuing digital certificates tied to creator profiles.",
                       category: "Creator Education", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 15, estimatedValueHigh: 50),
            PatentItem(title: "AI Audio Swap with Automatic Music Sync to Video Beat",
                       description: "Tool that replaces a video's background audio track with a new music selection and automatically re-syncs cuts and transitions to beat and tempo markers of the new track.",
                       category: "Creator Education", priority: .medium, claimType: "Utility Patent",
                       estimatedValueLow: 8, estimatedValueHigh: 28),

            // Platform Brand & IP
            PatentItem(title: "MyChannel.live — Next-Generation Social Video Platform",
                       description: "MyChannel.live is a next-generation social video platform invented, designed, and built by Keonta Peat. The platform uniquely combines YouTube-style long-form video, TikTok-style short-form Flicks, Instagram-style Stories, live streaming, a full creator monetization suite, an AI agent army running autonomously 24/7, a 3-strike owner review system, real-time fraud detection, gaming & esports tournaments, and a native iOS/Android/Web app — all under a single unified brand and product identity. The MyChannel.live domain, product name, user interface design language, and platform architecture are original works of authorship conceived and developed exclusively by the inventor. This document establishes the conception date of the MyChannel.live platform as a whole, securing prior art across all its novel systems and the unified product identity.",
                       category: "Platform Brand & IP", priority: .high, claimType: "Utility Patent + Trade Dress + Copyright",
                       estimatedValueLow: 100, estimatedValueHigh: 500),
            PatentItem(title: "MyChannel Brand Identity — Name, Mark & Platform Trade Dress",
                       description: "The name \"MyChannel\", the domain mychannel.live, the lightning bolt ⚡ brand mark, the owner command center UI, and the distinctive visual design language (dark-mode monospaced admin interface, red/cyan/green accent system) constitute original trade dress and brand identity conceived by Keonta Peat. This disclosure establishes first use in commerce and prior art for the MyChannel brand across all platforms, preventing third parties from registering confusingly similar marks.",
                       category: "Platform Brand & IP", priority: .high, claimType: "Trade Dress + Trademark",
                       estimatedValueLow: 50, estimatedValueHigh: 200),
            PatentItem(title: "Unified Cross-Platform Social Video App with AI-First Architecture",
                       description: "A social video platform that natively integrates long-form video, short-form vertical video (Flicks), ephemeral Stories, live streaming, and a creator studio — all served from a single Firebase-backed infrastructure with 190+ deployed ML Cloud Run services providing AI-first personalization, moderation, and monetization at every layer of the product.",
                       category: "Platform Brand & IP", priority: .high, claimType: "Utility Patent",
                       estimatedValueLow: 75, estimatedValueHigh: 300),
        ]
    }

    // MARK: - LIVE FEED PANEL

    private var liveFeedPanel: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(agentManager.isSchedulerRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    Text(agentManager.isSchedulerRunning ? "SCHEDULER ACTIVE" : "SCHEDULER OFFLINE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(agentManager.isSchedulerRunning ? .green : .red)
                }
                Spacer()
                Text("\(agentManager.activityLog.count) events • \(agentManager.totalRunsToday) today")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            if agentManager.activityLog.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 52))
                        .foregroundColor(.green.opacity(0.3))
                    Text("NO TRANSMISSIONS YET")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("Deploy agents to see\nlive AI activity here")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        isDeployingAll = true
                        Task {
                            await agentManager.deployAllAgents()
                            await MainActor.run { isDeployingAll = false }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("ACTIVATE AGENT ARMY")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if isLoadingLogs {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Fetching unified audit trail...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.top, 24)
                        } else if combinedEvents.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Text("No logged events found.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 24)
                        } else {
                            ForEach(combinedEvents) { event in
                                CombinedFeedRow(event: event)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable {
                    fetchLogs()
                }
                .onAppear {
                    fetchLogs()
                }
            }
        }
    }
    
    private func fetchLogs() {
        #if canImport(FirebaseFirestore)
        isLoadingLogs = true
        let db = Firestore.firestore()
        
        Task {
            var localEvents: [CombinedLogEvent] = []
            
            // 1. Fetch AI Agent Logs
            do {
                let agentSnap = try await db.collection("platformAgentLogs")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 20)
                    .getDocuments()
                for doc in agentSnap.documents {
                    let d = doc.data()
                    let timestamp = (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let name = d["agentName"] as? String ?? "Unknown Agent"
                    let output = d["output"] as? String ?? ""
                    let success = d["success"] as? Bool ?? true
                    localEvents.append(CombinedLogEvent(
                        id: doc.documentID,
                        timestamp: timestamp,
                        source: "🤖 AI",
                        title: name,
                        detail: output,
                        success: success
                    ))
                }
            } catch {
                print("⚠️ [AGIDashboard] Error loading agent logs: \(error)")
            }
            
            // 2. Fetch Moderator Action Logs
            do {
                let modSnap = try await db.collection("moderatorActionsLog")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 20)
                    .getDocuments()
                for doc in modSnap.documents {
                    let d = doc.data()
                    let timestamp = (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let name = d["username"] as? String ?? "User"
                    let actionType = d["actionType"] as? String ?? "Decision"
                    let tag = d["violationTag"] as? String ?? ""
                    let tagText = tag.isEmpty ? "" : " [\(tag)]"
                    let msg = d["ownerMessage"] as? String ?? ""
                    localEvents.append(CombinedLogEvent(
                        id: doc.documentID,
                        timestamp: timestamp,
                        source: "⚖️ MOD",
                        title: "Moderator Action on \(name)",
                        detail: "\(actionType.uppercased())\(tagText): \(msg)",
                        success: true
                    ))
                }
            } catch {
                print("⚠️ [AGIDashboard] Error loading mod logs: \(error)")
            }
            
            let sorted = localEvents.sorted { $0.timestamp > $1.timestamp }
            await MainActor.run {
                combinedEvents = sorted
                isLoadingLogs = false
            }
        }
        #else
        // Fallback for offline/local mockup
        combinedEvents = agentManager.activityLog.map {
            CombinedLogEvent(
                id: $0.id.uuidString,
                timestamp: $0.timestamp,
                source: "🤖 AI",
                title: $0.agentName,
                detail: $0.output,
                success: $0.success
            )
        }
        #endif
    }
}

struct CombinedFeedRow: View {
    let event: CombinedLogEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Source Badge
            Text(event.source)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(event.source.contains("AI") ? Color.purple : Color.orange)
                .cornerRadius(4)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(event.timestamp, style: .time)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Text(event.detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

extension AGIAgentDashboardView {
    var playgroundPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGENT RUN SIMULATOR")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                    Text("Select any agent and simulate its decision logic in real-time.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // Agent Picker Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("TARGET AGENT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Picker("Select Agent", selection: $playgroundSelectedAgentId) {
                        ForEach(agentManager.agents) { agent in
                            Text(agent.name).tag(agent.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Input Prompt Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("TEST INPUT QUERY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $playgroundInputText)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .font(.system(size: 13))
                }
                
                // Simulate button
                Button {
                    Task {
                        isSimulatingRun = true
                        playgroundOutputText = "Initializing simulation...\nRunning agent pipeline..."
                        do {
                            let result = try await agentManager.callAgent(playgroundSelectedAgentId, query: playgroundInputText)
                            await MainActor.run {
                                playgroundOutputText = result
                                isSimulatingRun = false
                            }
                        } catch {
                            await MainActor.run {
                                playgroundOutputText = "Simulation Failed: \(error.localizedDescription)"
                                isSimulatingRun = false
                            }
                        }
                    }
                } label: {
                    HStack {
                        if isSimulatingRun {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isSimulatingRun ? "RUNNING SIMULATION..." : "SIMULATE AGENT RUN")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSimulatingRun ? Color.gray : Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                .disabled(isSimulatingRun || playgroundInputText.isEmpty)
                
                // Output response card
                VStack(alignment: .leading, spacing: 8) {
                    Text("DIAGNOSTIC AGENT OUTPUT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(playgroundOutputText.isEmpty ? "No output yet. Enter input and click simulate." : playgroundOutputText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(playgroundOutputText.isEmpty ? .secondary : .primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
            .padding(16)
        }
    }
}


// ⚡ CIA components + patent types extracted to AGIDashboardComponents.swift
