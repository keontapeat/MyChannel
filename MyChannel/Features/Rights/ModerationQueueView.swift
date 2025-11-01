import SwiftUI

struct ModerationQueueView: View {
    @StateObject private var moderationService = ModerationService.shared
    @StateObject private var dmcaService = DMCAService.shared
    @State private var selectedFilter: QueueFilter = .all
    @State private var selectedContent: String?
    
    enum QueueFilter: String, CaseIterable {
        case all, needsReview, flagged, dmca
        
        var displayName: String {
            switch self {
            case .all: return "All"
            case .needsReview: return "Needs Review"
            case .flagged: return "Flagged"
            case .dmca: return "DMCA Claims"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(QueueFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content list
                List {
                    if selectedFilter == .dmca || selectedFilter == .all {
                        Section("DMCA Requests") {
                            ForEach(dmcaService.requests.filter { shouldShowRequest($0) }) { request in
                                DMCARequestRow(request: request) { requestId in
                                    selectedContent = requestId
                                }
                            }
                        }
                    }
                    
                    Section("Content Under Review") {
                        ForEach(0..<5) { index in
                            ModerationQueueItem(
                                contentId: "content_\(index)",
                                title: "Sample Content \(index + 1)",
                                type: .content,
                                score: Double.random(in: 0.3...0.9),
                                flaggedAt: Date().addingTimeInterval(-TimeInterval.random(in: 3600...86400))
                            ) { contentId in
                                selectedContent = contentId
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Moderation Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Refresh Queue") { refreshQueue() }
                        Button("Export Report") { exportReport() }
                        Button("Bulk Actions") { showBulkActions() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: Binding<Bool>(
                get: { selectedContent != nil },
                set: { if !$0 { selectedContent = nil } }
            )) {
                if let contentId = selectedContent {
                    ModerationDetailView(contentId: contentId)
                }
            }
        }
        .onAppear {
            dmcaService.listenToRequests()
        }
        .onDisappear {
            dmcaService.stopListening()
        }
    }
    
    private func shouldShowRequest(_ request: DMCARequest) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .dmca: return true
        case .needsReview: return request.status == .underReview
        case .flagged: return request.status == .submitted
        }
    }
    
    private func refreshQueue() {
        // Refresh moderation queue
    }
    
    private func exportReport() {
        // Export moderation report
    }
    
    private func showBulkActions() {
        // Show bulk actions sheet
    }
}

struct DMCARequestRow: View {
    let request: DMCARequest
    let onTap: (String) -> Void
    
    var body: some View {
        Button {
            onTap(request.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.copyrightedWork)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        
                        Text("From: \(request.claimantName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(request.status.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(request.status.color)
                            .cornerRadius(8)
                        
                        Text(request.submittedAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let deadline = request.counterNoticeDeadline, deadline > Date() {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text("Counter notice deadline: \(deadline, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct ModerationQueueItem: View {
    let contentId: String
    let title: String
    let type: ContentModerationType
    let score: Double
    let flaggedAt: Date
    let onTap: (String) -> Void
    
    private var scoreColor: Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        Button {
            onTap(contentId)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconForContentType(type))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    
                    HStack {
                        Text("Safety Score: \(Int(score * 100))%")
                            .font(.caption)
                            .foregroundColor(scoreColor)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(flaggedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForContentType(_ type: ContentModerationType) -> String {
        switch type {
        case .content: return "play.rectangle"
        case .metadata: return "info.circle"
        case .thumbnail: return "photo"
        case .copyright: return "c.circle"
        case .combined: return "square.stack"
        }
    }
}

struct ModerationDetailView: View {
    let contentId: String
    @Environment(\.dismiss) private var dismiss
    @State private var moderationResult: ContentModerationResult?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading details...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if let result = moderationResult {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Safety overview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Safety Assessment")
                                .font(.headline)
                            
                            HStack {
                                Text("Overall Score:")
                                Spacer()
                                Text("\(Int(result.confidence * 100))%")
                                    .foregroundColor(result.confidence >= 0.8 ? .green : (result.confidence >= 0.6 ? .orange : .red))
                            }
                            
                            HStack {
                                Text("Confidence:")
                                Spacer()
                                Text("\(Int(result.confidence * 100))%")
                            }
                            
                            HStack {
                                Text("Action Required:")
                                Spacer()
                                Text(result.requiresAction ? "Yes" : "No")
                                    .foregroundColor(result.requiresAction ? .red : .green)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Policy violations
                        if !result.violations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Policy Violations")
                                    .font(.headline)
                                
                                ForEach(result.violations, id: \.type.rawValue) { violation in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(violation.type.rawValue.capitalized, systemImage: "exclamationmark.triangle")
                                            .foregroundColor(.red)
                                        Text(violation.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Actions
                        VStack(spacing: 12) {
                            Button("Approve Content") {
                                Task { await approveContent() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Button("Restrict Content") {
                                Task { await restrictContent() }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            
                            Button("Remove Content") {
                                Task { await removeContent() }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Content Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadModerationDetails()
        }
    }
    
    private func loadModerationDetails() async {
        isLoading = true
        // Mock moderation result
        moderationResult = ContentModerationResult(
            type: .content,
            confidence: Double.random(in: 0.8...0.95),
            violations: [PolicyViolation(type: .spam, description: "Potential spam content", severity: .medium)],
            requiresAction: true,
            requiresHumanReview: true
        )
        isLoading = false
    }
    
    private func approveContent() async {
        dismiss()
    }
    
    private func restrictContent() async {
        dismiss()
    }
    
    private func removeContent() async {
        dismiss()
    }
}
