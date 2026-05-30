// ⚡ PERFORMANCE: Extracted from AGIAgentDashboardView.swift — independent compilation unit.
// CIA pills, tiles, sheets, patent types compile in parallel with the 835-line main view.
import SwiftUI

// MARK: - CIA Components

struct CIAPill: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
            Text(value).font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(color.opacity(0.1)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct CIAStatTile: View {
    let title: String; let value: String; let color: Color; let icon: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(color.opacity(0.08)).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct CIAActionTile: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).font(.system(size: 26)).foregroundColor(color)
                Text(title).font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary).multilineTextAlignment(.leading)
            }
            .frame(width: 100, height: 80).padding(10)
            .background(color.opacity(0.1)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
        }
    }
}

struct CIACategoryChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? Color.green : Color(.systemGray5)))
        }
    }
}

struct AgentRow: View {
    let agent: AGIAgentConfig
    let lastActivity: AgentActivity?
    let onTap: () -> Void
    @StateObject private var agentManager = AGIAgentManager.shared
    @State private var isRunning = false

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(agent.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Spacer()
                if agent.status == .live && agent.isEnabled {
                    Button {
                        isRunning = true
                        Task {
                            await agentManager.runAgent(agent.id)
                            await MainActor.run { isRunning = false }
                        }
                    } label: {
                        if isRunning {
                            ProgressView().scaleEffect(0.65).frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "play.circle.fill").font(.system(size: 20)).foregroundColor(.green)
                        }
                    }.disabled(isRunning)
                }
                Button(action: onTap) {
                    Image(systemName: "info.circle").font(.system(size: 17)).foregroundColor(.secondary)
                }
            }
            Text(agent.description).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            HStack {
                Label(agent.estimatedRevenue, systemImage: "dollarsign.circle.fill")
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.green)
                Spacer()
                if let a = lastActivity {
                    HStack(spacing: 3) {
                        Image(systemName: a.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 9)).foregroundColor(a.success ? .green : .red)
                        Text(a.timestamp, style: .relative)
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        Text("·\(a.latencyMs)ms")
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                    }
                } else {
                    Text(agent.status.rawValue)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(statusColor)
                }
            }
            if let a = lastActivity {
                Text(a.output).font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green.opacity(0.9)).lineLimit(2)
                    .padding(7).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.06)).cornerRadius(6)
            }
        }
        .padding(12).background(Color(.systemGray6)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(agent.status == .live ? Color.green.opacity(0.25) : Color.clear, lineWidth: 1))
    }
}

struct FeedRow: View {
    let activity: AgentActivity
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: activity.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 13)).foregroundColor(activity.success ? .green : .red)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(activity.agentName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("\(activity.latencyMs)ms")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                    Text(activity.timestamp, style: .relative)
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                }
                Text(activity.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(activity.success ? .green.opacity(0.9) : .red.opacity(0.8))
                    .lineLimit(3)
            }
        }
        .padding(10).background(Color(.systemGray6)).cornerRadius(8)
    }
}

// MARK: - Deploy Sheet

struct AgentDeploySheet: View {
    let agent: AGIAgentConfig
    @Environment(\.dismiss) private var dismiss
    @StateObject private var agentManager = AGIAgentManager.shared
    @State private var isDeploying = false
    @State private var isRunning = false
    @State private var runOutput = ""

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(agent.name).font(.system(size: 22, weight: .bold))
                            Text(agent.status.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(statusColor)
                        }
                        Spacer()
                        Label(agent.estimatedRevenue, systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(.green)
                    }

                    Divider()

                    infoRow("Description", agent.description)
                    infoRow("Impact", agent.impactDescription)
                    infoRow("Build Time", agent.estimatedBuildTime)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("REQUIRED DATA SOURCES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                        ForEach(agent.requiredDataSources, id: \.self) { src in
                            HStack(spacing: 6) {
                                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundColor(.green)
                                Text(src).font(.system(size: 13)).foregroundColor(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROMPT TEMPLATE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                        Text(agent.promptTemplate)
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                            .padding(10).background(Color(.systemGray6)).cornerRadius(8)
                    }

                    if !runOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LAST OUTPUT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                            Text(runOutput)
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.green)
                                .padding(10).background(Color.green.opacity(0.08)).cornerRadius(8)
                        }
                    }

                    VStack(spacing: 10) {
                        if agent.status != .live {
                            Button { doDeployAgent() } label: {
                                HStack {
                                    if isDeploying { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(0.8) }
                                    else { Image(systemName: "bolt.fill") }
                                    Text(isDeploying ? "DEPLOYING..." : "DEPLOY AGENT")
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(isDeploying ? Color.gray : Color.green)
                                .foregroundColor(.black).cornerRadius(12)
                            }.disabled(isDeploying)
                        }
                        if agent.status == .live {
                            Button {
                                isRunning = true
                                Task {
                                    let out = (try? await agentManager.callAgent(agent.id, query: "Provide one improvement for MyChannel right now.")) ?? "No output"
                                    await MainActor.run { runOutput = out; isRunning = false }
                                }
                            } label: {
                                HStack {
                                    if isRunning { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) }
                                    else { Image(systemName: "play.circle.fill") }
                                    Text(isRunning ? "RUNNING..." : "RUN NOW")
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(isRunning ? Color.gray : Color.blue)
                                .foregroundColor(.white).cornerRadius(12)
                            }.disabled(isRunning)

                            Button { agentManager.toggleAgent(agent.id, enabled: !agent.isEnabled) } label: {
                                Text(agent.isEnabled ? "DISABLE AGENT" : "ENABLE AGENT")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(agent.isEnabled ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                                    .foregroundColor(agent.isEnabled ? .orange : .green).cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Agent Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoRow(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
            Text(content).font(.system(size: 14)).foregroundColor(.primary)
        }
    }

    private func doDeployAgent() {
        isDeploying = true
        Task {
            try? await agentManager.deployAgent(agent.id)
            await MainActor.run { isDeploying = false; dismiss() }
        }
    }
}

// MARK: - Invention Disclosure Store

enum InventionDisclosureStore {
    private static let key = "MyChannel_InventionDisclosureDate"

    /// Load existing disclosure date or create + persist a new one stamped right now
    static func loadOrCreate() -> Date {
        if let stored = UserDefaults.standard.object(forKey: key) as? Date {
            return stored
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: key)
        return now
    }

    /// Generate the full disclosure text document
    static func generateDisclosureText(date: Date, items: [PatentItem]) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .long
        let dateStr = fmt.string(from: date)

        var lines: [String] = []
        lines.append("==========================================================")
        lines.append("  INVENTION DISCLOSURE DOCUMENT")
        lines.append("  MyChannel — Confidential & Proprietary")
        lines.append("==========================================================")
        lines.append("")
        let totalLow = items.reduce(0) { $0 + $1.estimatedValueLow }
        let totalHigh = items.reduce(0) { $0 + $1.estimatedValueHigh }
        let highCount = items.filter { $0.priority == .high }.count

        lines.append("Inventor:       Keonta Peat")
        lines.append("Product:        MyChannel (iOS / Android / Web Platform)")
        lines.append("Disclosure Date: \(dateStr)")
        lines.append("Document Type:  Pre-Patent Invention Disclosure (Prior Art Record)")
        lines.append("")
        lines.append("----------------------------------------------------------")
        lines.append("PORTFOLIO VALUE SUMMARY")
        lines.append("----------------------------------------------------------")
        lines.append("Total Patents Documented:  \(items.count)")
        lines.append("High-Value Patents:        \(highCount)")
        lines.append("Categories:                \(Set(items.map { $0.category }).count)")
        lines.append("Estimated Portfolio Value: $\(totalLow)M – $\(totalHigh)M")
        lines.append("(Based on comparable tech patent licensing & acquisition comps)")
        lines.append("")
        lines.append("----------------------------------------------------------")
        lines.append("LEGAL NOTICE")
        lines.append("----------------------------------------------------------")
        lines.append("This document constitutes a written record of invention")
        lines.append("conceived and reduced to practice by the inventor named above.")
        lines.append("The date of this document establishes conception date and")
        lines.append("creates prior art under 35 U.S.C. § 102. This document was")
        lines.append("generated, stored, and timestamped within the MyChannel")
        lines.append("iOS application and may be supplemented by email server")
        lines.append("timestamps, git commit history, and App Store submission records.")
        lines.append("")

        let categories = items.reduce(into: [String]()) { result, item in
            if !result.contains(item.category) { result.append(item.category) }
        }

        for category in categories {
            let catItems = items.filter { $0.category == category }
            lines.append("==========================================================")
            lines.append("  CATEGORY: \(category.uppercased())")
            lines.append("==========================================================")
            for (i, item) in catItems.enumerated() {
                lines.append("")
                lines.append("[\(i + 1)] \(item.title)")
                lines.append("    Claim Type:      \(item.claimType)")
                lines.append("    Priority:        \(item.priority == .high ? "HIGH VALUE" : "MEDIUM")")
                lines.append("    Est. Value:      $\(item.estimatedValueLow)M – $\(item.estimatedValueHigh)M")
                lines.append("    Description:")
                lines.append("    \(item.description)")
            }
            lines.append("")
        }

        lines.append("----------------------------------------------------------")
        lines.append("SIGNATURE OF CONCEPTION")
        lines.append("----------------------------------------------------------")
        lines.append("I, Keonta Peat, hereby declare that I am the original")
        lines.append("inventor of the subject matter described in this document.")
        lines.append("This disclosure was first recorded on: \(dateStr)")
        lines.append("")
        lines.append("Inventor Signature: Keonta Peat")
        lines.append("Date: \(dateStr)")
        lines.append("")
        lines.append("==========================================================")
        lines.append("  END OF INVENTION DISCLOSURE DOCUMENT")
        lines.append("  © \(Calendar.current.component(.year, from: date)) Keonta Peat / MyChannel. All Rights Reserved.")
        lines.append("==========================================================")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Protection Row

struct ProtectionRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Patent Supporting Types & Views

struct PatentItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let priority: PatentPriority
    let claimType: String
    let estimatedValueLow: Int
    let estimatedValueHigh: Int

    enum PatentPriority {
        case high, medium
    }
}

struct PatentStatPill: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
            Text(value).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.1)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

struct PatentItemCard: View {
    let item: PatentItem
    @State private var expanded = false

    var priorityColor: Color { item.priority == .high ? .red : .orange }
    var priorityLabel: String { item.priority == .high ? "HIGH VALUE" : "MEDIUM" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Text(priorityLabel)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(priorityColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(priorityColor.opacity(0.12))
                                .cornerRadius(4)
                            Text(item.claimType)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.purple.opacity(0.8))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EST. PATENT VALUE")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("$\(item.estimatedValueLow)M – $\(item.estimatedValueHigh)M")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        Text(item.priority == .high ? "🔥 HIGH PRIORITY" : "⚡ MEDIUM")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(item.priority == .high ? .red : .orange)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((item.priority == .high ? Color.red : Color.orange).opacity(0.12))
                            .cornerRadius(6)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    NavigationStack { AGIAgentDashboardView() }
}

