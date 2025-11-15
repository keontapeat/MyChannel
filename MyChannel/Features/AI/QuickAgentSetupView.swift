//
//  QuickAgentSetupView.swift
//  MyChannel
//
//  ⚡ SUPER SIMPLE AGENT SETUP - Just paste IDs and click!
//

import SwiftUI

struct QuickAgentSetupView: View {
    @StateObject private var agentManager = AGIAgentManager.shared
    @State private var agentIds: [String: String] = [
        "agent-002-creator-coach": "",
        "agent-003-cps-guardian": "",
        "agent-004-support": "",
        "agent-005-debugger": "",
        "agent-006-universe-company": ""
    ]
    @State private var isDeploying = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🚀 Quick Agent Setup")
                            .font(AppTheme.Typography.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Paste your Vertex AI Agent IDs below")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Agent ID Input Fields
                    VStack(spacing: 16) {
                        AgentIDField(
                            title: "1. Creator Coach Agent",
                            placeholder: "Paste Vertex AI Agent ID",
                            text: Binding(
                                get: { agentIds["agent-002-creator-coach"] ?? "" },
                                set: { agentIds["agent-002-creator-coach"] = $0 }
                            )
                        )
                        
                        AgentIDField(
                            title: "2. CPS Guardian Agent",
                            placeholder: "Paste Vertex AI Agent ID",
                            text: Binding(
                                get: { agentIds["agent-003-cps-guardian"] ?? "" },
                                set: { agentIds["agent-003-cps-guardian"] = $0 }
                            )
                        )
                        
                        AgentIDField(
                            title: "3. Support Agent",
                            placeholder: "Paste Vertex AI Agent ID",
                            text: Binding(
                                get: { agentIds["agent-004-support"] ?? "" },
                                set: { agentIds["agent-004-support"] = $0 }
                            )
                        )
                        
                        AgentIDField(
                            title: "4. Super AGI Code Debugger",
                            placeholder: "Paste Vertex AI Agent ID",
                            text: Binding(
                                get: { agentIds["agent-005-debugger"] ?? "" },
                                set: { agentIds["agent-005-debugger"] = $0 }
                            )
                        )
                        
                        AgentIDField(
                            title: "5. Universe Company Agent",
                            placeholder: "Paste Vertex AI Agent ID",
                            text: Binding(
                                get: { agentIds["agent-006-universe-company"] ?? "" },
                                set: { agentIds["agent-006-universe-company"] = $0 }
                            )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Deploy Button
                    Button(action: deployAllAgents) {
                        HStack {
                            if isDeploying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "rocket.fill")
                            }
                            Text(isDeploying ? "Deploying..." : "Deploy All Agents")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            allIdsFilled ? AppTheme.Colors.primary : Color.gray
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!allIdsFilled || isDeploying)
                    .padding(.horizontal, 20)
                    
                    // Status
                    if showSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("All agents deployed successfully! 🎉")
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📋 How to get Agent IDs:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(number: "1", text: "Go to Vertex AI → Agent Engine")
                            InstructionRow(number: "2", text: "Click 'Develop agent' for each agent")
                            InstructionRow(number: "3", text: "Copy the prompt from AGIAgentConfig.swift")
                            InstructionRow(number: "4", text: "Create agent and copy the Agent ID")
                            InstructionRow(number: "5", text: "Paste IDs above and click Deploy!")
                        }
                    }
                    .padding(20)
                    .background(AppTheme.Colors.backgroundSecondary)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Agent Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var allIdsFilled: Bool {
        agentIds.values.allSatisfy { !$0.isEmpty }
    }
    
    private func deployAllAgents() {
        isDeploying = true
        showSuccess = false
        
        Task {
            // Remove empty entries
            let validIds = agentIds.filter { !$0.value.isEmpty }
            
            // Add all IDs
            AGIAgentBulkUpdater.shared.bulkAddAgentIds(validIds)
            
            // Deploy all
            await AGIAgentBulkUpdater.shared.bulkDeployAgents(Array(validIds.keys))
            
            isDeploying = false
            showSuccess = true
            
            // Reset after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccess = false
            }
        }
    }
}

struct AgentIDField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.Colors.primary)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

#Preview {
    QuickAgentSetupView()
}





