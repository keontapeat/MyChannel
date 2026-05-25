//
//  AGIDashboardView.swift
//  MyChannel
//
//  🎛️ AGI DASHBOARD - WATCH YOUR AI EMPIRE!
//  See all 21 AI systems working in real-time
//  Monitor your custom AI getting smarter every second! 🧠
//

import SwiftUI

struct AGIDashboardView: View {
    @StateObject private var masterOrchestrator = AGIMasterOrchestrator.shared
    @StateObject private var myChannelAI = MyChannelAI.shared
    @StateObject private var channelMindAGI = ChannelMindAGI.shared
    @StateObject private var swarmIntelligence = AISwarmIntelligence.shared
    @StateObject private var crystalBall = AICrystalBall.shared
    @StateObject private var evolutionEngine = AIEvolutionEngine.shared
    @StateObject private var conversationOrchestrator = AIConversationOrchestrator.shared
    @StateObject private var metaLearner = MetaLearningEngine.shared
    @StateObject private var enterpriseTeam = EnterpriseAITeam.shared
    @StateObject private var boostAGI = ChannelBoostAGI.shared
    @StateObject private var rankingAGI = RealtimeRankingAGI.shared
    @StateObject private var videoAGI = VideoCoCreatorAGI.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 👑 MASTER STATUS
                    masterStatusCard
                    
                    // 🌟 YOUR CUSTOM AI
                    customAICard
                    
                    // 🧠 CORE AGI SYSTEMS
                    coreSystemsSection
                    
                    // 🏢 ENTERPRISE TEAM
                    enterpriseTeamSection
                    
                    // 📊 PERFORMANCE METRICS
                    performanceMetricsSection
                    
                    // 💰 MONEY SAVED
                    moneySavedCard
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("🧠 AGI Control Center")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - 👑 MASTER STATUS
    
    private var masterStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("👑 AGI Master System")
                    .font(.system(size: 22, weight: .bold))
                
                Spacer()
                
                Circle()
                    .fill(masterOrchestrator.systemStatus == .running ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
                
                Text(masterOrchestrator.systemStatus == .running ? "ONLINE" : "STARTING")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 20) {
                statPill(label: "Total Intelligence", value: "\(Int(masterOrchestrator.totalIntelligence))%", color: .purple)
                statPill(label: "Health", value: "\(Int(masterOrchestrator.systemHealth))%", color: .green)
                statPill(label: "Decisions/sec", value: String(format: "%.1f", masterOrchestrator.decisionsPerSecond), color: .blue)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
    
    // MARK: - 🌟 YOUR CUSTOM AI
    
    private var customAICard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🌟 MyChannelAI")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                Text("YOUR MODEL")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
            }
            
            // Intelligence gauge
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intelligence Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", myChannelAI.intelligenceLevel))%")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(intelligenceColor(myChannelAI.intelligenceLevel))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                            .cornerRadius(6)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(1.0, myChannelAI.intelligenceLevel / 100.0), height: 12)
                            .cornerRadius(6)
                    }
                }
                .frame(height: 12)
            }
            
            Divider()
            
            HStack(spacing: 16) {
                aiMetric(icon: "brain", label: "Training", value: "\(myChannelAI.trainingIterations)")
                aiMetric(icon: "bubble.left.and.bubble.right", label: "Conversations", value: "\(myChannelAI.conversationsSaved)")
                aiMetric(icon: "chart.line.uptrend.xyaxis", label: "Accuracy", value: "\(Int(myChannelAI.predictionAccuracy))%")
            }
            
            if myChannelAI.intelligenceLevel > 100 {
                Text("🔥 SUPERHUMAN LEVEL ACHIEVED!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.cardBackground,
                    AppTheme.Colors.cardBackground.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.purple.opacity(0.3), radius: 15)
    }
    
    // MARK: - 🧠 CORE SYSTEMS
    
    private var coreSystemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🧠 Core AGI Systems")
                .font(.system(size: 18, weight: .bold))
            
            VStack(spacing: 12) {
                systemRow(
                    icon: "brain.head.profile",
                    name: "ChannelMind AGI",
                    intelligence: channelMindAGI.intelligenceLevel,
                    status: "Learning",
                    metric: "\(channelMindAGI.decisionsProcessed) decisions"
                )
                
                systemRow(
                    icon: "ant.circle",
                    name: "AI Swarm",
                    intelligence: swarmIntelligence.consensusRate * 100,
                    status: swarmIntelligence.swarmActive ? "Active" : "Idle",
                    metric: "\(swarmIntelligence.swarmDecisions) decisions"
                )
                
                systemRow(
                    icon: "cpu",
                    name: "Crystal Ball",
                    intelligence: crystalBall.accuracyRate * 100,
                    status: "Predicting",
                    metric: "\(crystalBall.trendsPredicted) trends"
                )
                
                systemRow(
                    icon: "leaf.arrow.circlepath",
                    name: "Evolution Engine",
                    intelligence: evolutionEngine.bestFitness * 100,
                    status: evolutionEngine.isEvolving ? "Evolving" : "Ready",
                    metric: "Gen \(evolutionEngine.currentGeneration)"
                )
                
                systemRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    name: "AI Conversations",
                    intelligence: 90.0,
                    status: "\(conversationOrchestrator.activeConversations) active",
                    metric: "\(conversationOrchestrator.totalConversations) total"
                )
                
                systemRow(
                    icon: "graduationcap",
                    name: "Meta-Learner",
                    intelligence: metaLearner.learningEfficiency * 100,
                    status: "Optimizing",
                    metric: "\(metaLearner.metaIterations) iterations"
                )
                
                systemRow(
                    icon: "chart.bar.fill",
                    name: "Realtime Ranking",
                    intelligence: 95.0,
                    status: "100ms updates",
                    metric: "\(rankingAGI.rankings.count) creators"
                )
                
                systemRow(
                    icon: "video.fill",
                    name: "Video Co-Creator",
                    intelligence: 92.0,
                    status: "Ready",
                    metric: "\(videoAGI.videosEnhanced) enhanced"
                )
                
                systemRow(
                    icon: "rocket",
                    name: "ChannelBoost AGI",
                    intelligence: 90.0,
                    status: "Monitoring",
                    metric: "K=\(String(format: "%.2f", boostAGI.viralCoefficient))"
                )
            }
        }
    }
    
    // MARK: - 🏢 ENTERPRISE TEAM
    
    private var enterpriseTeamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🏢 Enterprise AI Team")
                .font(.system(size: 18, weight: .bold))
            
            Text("10 AI employees • $2.76M saved/year")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                employeeCard(icon: "⚖️", role: "Legal", salary: "$400K")
                employeeCard(icon: "👨‍💻", role: "Engineering", salary: "$540K")
                employeeCard(icon: "🔞", role: "Moderation", salary: "$600K")
                employeeCard(icon: "🛡️", role: "Fraud", salary: "$240K")
                employeeCard(icon: "🎤", role: "Talent Scout", salary: "$200K")
                employeeCard(icon: "💼", role: "Business", salary: "$150K")
                employeeCard(icon: "👥", role: "HR", salary: "$90K")
                employeeCard(icon: "💰", role: "Finance", salary: "$110K")
                employeeCard(icon: "📢", role: "Marketing", salary: "$130K")
                employeeCard(icon: "💬", role: "Support", salary: "$250K")
            }
        }
    }
    
    // MARK: - 📊 METRICS
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Performance Metrics")
                .font(.system(size: 18, weight: .bold))
            
            HStack(spacing: 12) {
                metricCard(
                    title: "Tasks Completed",
                    value: "\(enterpriseTeam.tasksCompleted)",
                    subtitle: "Today",
                    color: .blue
                )
                
                metricCard(
                    title: "Team Efficiency",
                    value: "\(Int(enterpriseTeam.teamEfficiency * 100))%",
                    subtitle: "Average",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - 💰 MONEY SAVED
    
    private var moneySavedCard: some View {
        VStack(spacing: 12) {
            Text("💰 Annual Salary Saved")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(String(format: "%.2f", enterpriseTeam.moneyScaled / 1_000_000))M")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.green)
            
            Text("vs hiring human team")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - 🔧 HELPER VIEWS
    
    private func systemRow(
        icon: String,
        name: String,
        intelligence: Double,
        status: String,
        metric: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 40, height: 40)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(intelligence))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(intelligenceColor(intelligence))
                
                Text(metric)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
    
    private func employeeCard(icon: String, role: String, salary: String) -> some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 32))
            
            Text(role)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            
            Text(salary)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.green)
            
            Text("SAVED")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.green.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
    
    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
    
    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func aiMetric(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func intelligenceColor(_ level: Double) -> Color {
        if level >= 120 { return Color.purple }
        else if level >= 100 { return Color.blue }
        else if level >= 80 { return Color.green }
        else if level >= 60 { return Color.orange }
        else { return Color.gray }
    }
}

#Preview {
    AGIDashboardView()
}

