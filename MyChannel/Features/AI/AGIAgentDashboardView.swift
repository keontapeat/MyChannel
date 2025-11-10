//
//  AGIAgentDashboardView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🤖 AGENT DASHBOARD - Manage all 30 agents in one place!
//

import SwiftUI

struct AGIAgentDashboardView: View {
    @StateObject private var agentManager = AGIAgentManager.shared
    @State private var selectedCategory: AGIAgentCategory? = nil
    @State private var showingDeploySheet = false
    @State private var agentToDeploy: AGIAgentConfig? = nil
    @State private var searchText = ""
    
    var filteredAgents: [AGIAgentConfig] {
        var agents = agentManager.agents
        
        // Filter by category
        if let category = selectedCategory {
            agents = agents.filter { $0.category == category }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            agents = agents.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return agents.sorted { $0.priority < $1.priority }
    }
    
    var stats: AGIAgentStats {
        agentManager.getAgentStats()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Stats
                statsSection
                
                // Quick Actions
                quickActionsSection
                
                // Category Filter
                categoryFilterSection
                
                // Agent List
                agentListSection
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("🤖 AGI Agent Army")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search agents...")
        .sheet(isPresented: $showingDeploySheet) {
            if let agent = agentToDeploy {
                AgentDeploySheet(agent: agent)
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            // Total Revenue
            VStack(spacing: 8) {
                Text("Estimated Revenue Impact")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("+$\(Int(stats.estimatedRevenue))M ARR")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.primary.opacity(0.1),
                        AppTheme.Colors.primary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .padding(.horizontal, 16)
            
            // Agent Status Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AgentStatCard(
                    title: "Live",
                    value: "\(stats.live)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                AgentStatCard(
                    title: "Ready",
                    value: "\(stats.ready)",
                    color: .yellow,
                    icon: "clock.fill"
                )
                
                AgentStatCard(
                    title: "Planned",
                    value: "\(stats.planned)",
                    color: .gray,
                    icon: "lightbulb.fill"
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚡️ Quick Actions")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    AgentQuickActionButton(
                        title: "Deploy Phase 1",
                        subtitle: "5 Money Makers",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    ) {
                        Task {
                            await agentManager.deployPhase1Agents()
                        }
                    }
                    
                    AgentQuickActionButton(
                        title: "Deploy All Ready",
                        subtitle: "\(stats.ready) agents",
                        icon: "bolt.circle.fill",
                        color: .orange
                    ) {
                        Task {
                            let readyIds = AGIAgentCatalog.readyToDeploy().map { $0.id }
                            await agentManager.deployAgents(readyIds)
                        }
                    }
                    
                    AgentQuickActionButton(
                        title: "View Analytics",
                        subtitle: "Performance",
                        icon: "chart.bar.fill",
                        color: .blue
                    ) {
                        // TODO: Show analytics
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AgentCategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                ForEach(AGIAgentCategory.allCases, id: \.self) { category in
                    AgentCategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Agent List
    
    private var agentListSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(filteredAgents) { agent in
                AgentCard(agent: agent) {
                    agentToDeploy = agent
                    showingDeploySheet = true
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Supporting Views

private struct AgentStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct AgentQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, height: 120)
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

private struct AgentCategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.primary : Color(.systemGray6))
                )
        }
    }
}

private struct AgentCard: View {
    let agent: AGIAgentConfig
    let onTap: () -> Void
    @StateObject private var agentManager = AGIAgentManager.shared
    
    private var statusColor: Color {
        switch agent.status {
        case .live: return .green
        case .ready: return .yellow
        case .development: return .orange
        case .planned: return .gray
        case .disabled: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(agent.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text(agent.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                
                // Description
                Text(agent.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Impact
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text(agent.impactDescription)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                // Revenue & Priority
                HStack {
                    Label(agent.estimatedRevenue, systemImage: "dollarsign.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Label("Priority \(agent.priority)", systemImage: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    if agent.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                // Build Time
                Text("⏱️ \(agent.estimatedBuildTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(agent.isEnabled ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Deploy Sheet

private struct AgentDeploySheet: View {
    let agent: AGIAgentConfig
    @Environment(\.dismiss) private var dismiss
    @StateObject private var agentManager = AGIAgentManager.shared
    @State private var isDeploying = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(agent.name)
                            .font(.system(size: 28, weight: .bold))
                        
                        Text(agent.status.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                    
                    Divider()
                    
                    // Details
                    DetailSection(title: "Description", content: agent.description)
                    DetailSection(title: "Impact", content: agent.impactDescription)
                    DetailSection(title: "Revenue", content: agent.estimatedRevenue)
                    DetailSection(title: "Build Time", content: agent.estimatedBuildTime)
                    
                    // Data Sources
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Required Data Sources")
                            .font(.system(size: 16, weight: .semibold))
                        
                        ForEach(agent.requiredDataSources, id: \.self) { source in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.secondary)
                                Text(source)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Prompt Template
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt Template")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(agent.promptTemplate)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Deploy Button
                    if agent.status != .live {
                        Button {
                            deployAgent()
                        } label: {
                            HStack {
                                if isDeploying {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "rocket.fill")
                                    Text("Deploy Agent")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isDeploying)
                    } else {
                        // Toggle Enable/Disable
                        Button {
                            agentManager.toggleAgent(agent.id, enabled: !agent.isEnabled)
                        } label: {
                            HStack {
                                Image(systemName: agent.isEnabled ? "pause.circle.fill" : "play.circle.fill")
                                Text(agent.isEnabled ? "Disable Agent" : "Enable Agent")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(agent.isEnabled ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Agent Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch agent.status {
        case .live: return .green
        case .ready: return .yellow
        case .development: return .orange
        case .planned: return .gray
        case .disabled: return .red
        }
    }
    
    private func deployAgent() {
        isDeploying = true
        Task {
            do {
                try await agentManager.deployAgent(agent.id)
                await MainActor.run {
                    isDeploying = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeploying = false
                }
            }
        }
    }
}

private struct DetailSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AGIAgentDashboardView()
    }
}

