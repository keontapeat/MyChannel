//
//  AGIAgentManager.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🚀 AGENT MANAGER - Easy deployment and management
//

import Foundation
import Combine

@MainActor
class AGIAgentManager: ObservableObject {
    static let shared = AGIAgentManager()
    
    @Published var agents: [AGIAgentConfig] = AGIAgentCatalog.allAgents
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {
        loadAgentStates()
    }
    
    // MARK: - Agent Management
    
    /// Add Vertex AI Agent ID to an agent (after creating in Vertex AI console)
    func addVertexAIAgentId(_ agentId: String, vertexAIAgentId: String) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            // Create updated config with new Vertex AI ID
            let agent = agents[index]
            let updatedConfig = AGIAgentConfig(
                id: agent.id,
                name: agent.name,
                category: agent.category,
                status: agent.status,
                description: agent.description,
                impactDescription: agent.impactDescription,
                estimatedRevenue: agent.estimatedRevenue,
                vertexAIAgentId: vertexAIAgentId, // ✅ Add the Vertex AI ID
                promptTemplate: agent.promptTemplate,
                requiredDataSources: agent.requiredDataSources,
                outputFormat: agent.outputFormat,
                isEnabled: agent.isEnabled,
                priority: agent.priority,
                estimatedBuildTime: agent.estimatedBuildTime,
                runInterval: agent.runInterval
            )
            agents[index] = updatedConfig
            saveAgentStates()
            print("✅ Added Vertex AI ID to \(agent.name): \(vertexAIAgentId)")
        }
    }
    
    /// Deploy an agent to Vertex AI (updates status to live)
    func deployAgent(_ agentId: String) async throws {
        guard let agent = agents.first(where: { $0.id == agentId }) else {
            throw AGIError.agentNotFound
        }
        
        guard agent.vertexAIAgentId != nil else {
            throw AGIError.missingVertexAIId
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🚀 Deploying agent: \(agent.name)")
        
        // Update agent status
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            let agent = agents[index]
            let updatedConfig = AGIAgentConfig(
                id: agent.id,
                name: agent.name,
                category: agent.category,
                status: .live, // ✅ Mark as live
                description: agent.description,
                impactDescription: agent.impactDescription,
                estimatedRevenue: agent.estimatedRevenue,
                vertexAIAgentId: agent.vertexAIAgentId,
                promptTemplate: agent.promptTemplate,
                requiredDataSources: agent.requiredDataSources,
                outputFormat: agent.outputFormat,
                isEnabled: true, // ✅ Enable it
                priority: agent.priority,
                estimatedBuildTime: agent.estimatedBuildTime,
                runInterval: agent.runInterval
            )
            agents[index] = updatedConfig
            saveAgentStates()
        }
        
        print("✅ Agent deployed: \(agent.name)")
    }
    
    /// Enable/disable an agent
    func toggleAgent(_ agentId: String, enabled: Bool) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].isEnabled = enabled
            saveAgentStates()
            print("\(enabled ? "✅" : "❌") Agent \(agents[index].name) \(enabled ? "enabled" : "disabled")")
        }
    }
    
    /// Call an agent with a query
    func callAgent(_ agentId: String, query: String, context: [String: Any] = [:]) async throws -> String {
        guard let agent = agents.first(where: { $0.id == agentId }) else {
            throw AGIError.agentNotFound
        }
        
        guard agent.isEnabled else {
            throw AGIError.agentDisabled
        }
        
        // If agent has Vertex AI ID, use it
        if let vertexAIId = agent.vertexAIAgentId {
            return try await callVertexAI(agentId: vertexAIId, query: query, context: context)
        }
        
        // Otherwise use prompt template
        return try await callWithTemplate(agent: agent, query: query, context: context)
    }
    
    // MARK: - Vertex AI Integration
    
    private func callVertexAI(agentId: String, query: String, context: [String: Any]) async throws -> String {
        // TODO: Integrate with actual Vertex AI API
        // For now, return mock response
        return "Mock response from Vertex AI agent \(agentId)"
    }
    
    private func callWithTemplate(agent: AGIAgentConfig, query: String, context: [String: Any]) async throws -> String {
        // TODO: Use Gemini API with prompt template
        var prompt = agent.promptTemplate
        
        // Replace template variables
        prompt = prompt.replacingOccurrences(of: "{{query}}", with: query)
        for (key, value) in context {
            prompt = prompt.replacingOccurrences(of: "{{\(key)}}", with: "\(value)")
        }
        
        return "Mock response using template for \(agent.name)"
    }
    
    // MARK: - Batch Operations
    
    /// Deploy multiple agents at once
    func deployAgents(_ agentIds: [String]) async {
        for agentId in agentIds {
            do {
                try await deployAgent(agentId)
            } catch {
                print("❌ Failed to deploy agent \(agentId): \(error)")
                lastError = error.localizedDescription
            }
        }
    }
    
    /// Deploy all Phase 1 agents (Money Makers)
    func deployPhase1Agents() async {
        let phase1Ids = [
            "agent-007-dynamic-pricing",
            "agent-008-ad-placement",
            "agent-009-fraud-detection",
            "agent-010-upsell-crosssell",
            "agent-011-match-fairness"
        ]
        await deployAgents(phase1Ids)
    }
    
    // MARK: - Analytics
    
    func getAgentStats() -> AGIAgentStats {
        let total = agents.count
        let live = agents.filter { $0.status == .live }.count
        let ready = agents.filter { $0.status == .ready }.count
        let planned = agents.filter { $0.status == .planned }.count
        
        let totalRevenue = agents.reduce(0.0) { sum, agent in
            // Parse revenue string (e.g., "+$20M ARR" -> 20.0)
            let revenueString = agent.estimatedRevenue
            let number = revenueString
                .replacingOccurrences(of: "+$", with: "")
                .replacingOccurrences(of: "M ARR", with: "")
                .replacingOccurrences(of: " saved", with: "")
                .replacingOccurrences(of: "Save $", with: "")
                .replacingOccurrences(of: "M/year", with: "")
            return sum + (Double(number) ?? 0)
        }
        
        return AGIAgentStats(
            total: total,
            live: live,
            ready: ready,
            planned: planned,
            estimatedRevenue: totalRevenue
        )
    }
    
    // MARK: - Persistence
    
    private func saveAgentStates() {
        // Save agent states to UserDefaults
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(agents) {
            UserDefaults.standard.set(data, forKey: "AGIAgentStates")
        }
    }
    
    private func loadAgentStates() {
        // Load saved agent states
        if let data = UserDefaults.standard.data(forKey: "AGIAgentStates") {
            let decoder = JSONDecoder()
            if let savedAgents = try? decoder.decode([AGIAgentConfig].self, from: data) {
                // Merge with default agents (in case new agents were added)
                var merged = AGIAgentCatalog.allAgents
                for savedAgent in savedAgents {
                    if let index = merged.firstIndex(where: { $0.id == savedAgent.id }) {
                        merged[index] = savedAgent
                    }
                }
                agents = merged
                return
            }
        }
        
        // If no saved state, use default
        agents = AGIAgentCatalog.allAgents
    }
}

// MARK: - Supporting Types

struct AGIAgentStats {
    let total: Int
    let live: Int
    let ready: Int
    let planned: Int
    let estimatedRevenue: Double
    
    var livePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(live) / Double(total) * 100
    }
}

enum AGIError: LocalizedError {
    case agentNotFound
    case agentDisabled
    case deploymentFailed
    case invalidResponse
    case missingVertexAIId
    
    var errorDescription: String? {
        switch self {
        case .agentNotFound: return "Agent not found"
        case .agentDisabled: return "Agent is disabled"
        case .deploymentFailed: return "Failed to deploy agent"
        case .missingVertexAIId: return "Agent missing Vertex AI ID. Add it first using addVertexAIAgentId()"
        case .invalidResponse: return "Invalid agent response"
        }
    }
}

