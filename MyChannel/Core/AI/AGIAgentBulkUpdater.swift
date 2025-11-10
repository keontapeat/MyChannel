//
//  AGIAgentBulkUpdater.swift
//  MyChannel
//
//  🚀 BULK AGENT UPDATER - Add all Vertex AI IDs at once!
//  Just paste your agent IDs and run this!
//

import Foundation

@MainActor
class AGIAgentBulkUpdater {
    static let shared = AGIAgentBulkUpdater()
    
    /// Bulk add Vertex AI Agent IDs
    /// Format: ["agent-id": "vertex-ai-id"]
    func bulkAddAgentIds(_ agentIds: [String: String]) {
        for (agentId, vertexAIAgentId) in agentIds {
            AGIAgentManager.shared.addVertexAIAgentId(agentId, vertexAIAgentId: vertexAIAgentId)
        }
        print("✅ Added \(agentIds.count) Vertex AI Agent IDs")
    }
    
    /// Bulk deploy agents (marks all as live)
    func bulkDeployAgents(_ agentIds: [String]) async {
        for agentId in agentIds {
            do {
                try await AGIAgentManager.shared.deployAgent(agentId)
                print("✅ Deployed: \(agentId)")
            } catch {
                print("❌ Failed to deploy \(agentId): \(error)")
            }
        }
    }
    
    /// Quick setup: Add all 5 ready agents at once
    func setupReadyAgents(agentIds: [String: String]) async {
        // Expected format:
        // [
        //     "agent-002-creator-coach": "your-vertex-ai-id-1",
        //     "agent-003-cps-guardian": "your-vertex-ai-id-2",
        //     "agent-004-support": "your-vertex-ai-id-3",
        //     "agent-005-debugger": "your-vertex-ai-id-4",
        //     "agent-006-universe-company": "your-vertex-ai-id-5"
        // ]
        
        bulkAddAgentIds(agentIds)
        await bulkDeployAgents(Array(agentIds.keys))
    }
}

// MARK: - Quick Setup Function (Paste your IDs here and run!)

func setupMyChannelAgents() {
    // 🚀 PASTE YOUR VERTEX AI AGENT IDs HERE:
    let agentIds: [String: String] = [
        "agent-002-creator-coach": "PASTE-ID-HERE",
        "agent-003-cps-guardian": "PASTE-ID-HERE",
        "agent-004-support": "PASTE-ID-HERE",
        "agent-005-debugger": "PASTE-ID-HERE",
        "agent-006-universe-company": "PASTE-ID-HERE"
    ]
    
    // Run it! (Must be called from MainActor context)
    Task { @MainActor in
        await AGIAgentBulkUpdater.shared.setupReadyAgents(agentIds: agentIds)
    }
}

