//
//  FeaturedVideoAdminView.swift
//  MyChannel
//
//  Admin interface for managing featured video requests and active featured videos
//

import SwiftUI

struct FeaturedVideoAdminView: View {
    @StateObject private var adminService = FeaturedVideoAdminService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: AdminTab = .pending
    @State private var showingApprovalSheet: FeaturedVideoRequest?
    @State private var showingRejectionSheet: FeaturedVideoRequest?
    @State private var rejectionReason: String = ""
    @State private var isLoading: Bool = false
    
    enum AdminTab: String, CaseIterable {
        case pending = "Pending Requests"
        case active = "Active Featured"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("View", selection: $selectedTab) {
                    ForEach(AdminTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
                
                // Content
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else {
                        Group {
                            switch selectedTab {
                            case .pending:
                                pendingRequestsView
                            case .active:
                                activeFeaturedView
                            }
                        }
                    }
                }
            }
            .navigationTitle("Featured Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    await adminService.loadPendingRequests()
                    await adminService.loadActiveFeatured()
                }
            }
            .sheet(item: $showingApprovalSheet) { request in
                ApprovalSheetView(request: request) { approved in
                    if approved {
                        Task {
                            await approveRequest(request)
                        }
                    }
                    showingApprovalSheet = nil
                }
            }
            .sheet(item: $showingRejectionSheet) { request in
                RejectionSheetView(
                    request: request,
                    reason: $rejectionReason
                ) { rejected in
                    if rejected {
                        Task {
                            await rejectRequest(request)
                        }
                    }
                    showingRejectionSheet = nil
                    rejectionReason = ""
                }
            }
        }
    }
    
    // MARK: - Pending Requests View
    private var pendingRequestsView: some View {
        LazyVStack(spacing: 16) {
            if adminService.pendingRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Pending Requests")
                        .font(.headline)
                    Text("All featured video requests have been reviewed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(adminService.pendingRequests) { request in
                    FeaturedRequestRow(request: request) {
                        showingApprovalSheet = request
                    } onReject: {
                        showingRejectionSheet = request
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Active Featured View
    private var activeFeaturedView: some View {
        LazyVStack(spacing: 16) {
            if adminService.activeFeaturedVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text("No Active Featured Videos")
                        .font(.headline)
                    Text("No videos are currently featured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(adminService.activeFeaturedVideos) { active in
                    ActiveFeaturedRow(activeFeatured: active) {
                        Task {
                            await removeFeatured(active)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    private func approveRequest(_ request: FeaturedVideoRequest) async {
        isLoading = true
        do {
            // Get current user ID (admin)
            let adminUserId = "admin_user_id" // TODO: Get from auth service
            try await adminService.approveRequest(request, adminUserId: adminUserId)
        } catch {
            print("❌ Error approving request: \(error)")
        }
        isLoading = false
        await adminService.loadPendingRequests()
        await adminService.loadActiveFeatured()
    }
    
    private func rejectRequest(_ request: FeaturedVideoRequest) async {
        isLoading = true
        do {
            let adminUserId = "admin_user_id" // TODO: Get from auth service
            try await adminService.rejectRequest(request, adminUserId: adminUserId, reason: rejectionReason)
        } catch {
            print("❌ Error rejecting request: \(error)")
        }
        isLoading = false
        await adminService.loadPendingRequests()
    }
    
    private func removeFeatured(_ active: ActiveFeaturedVideo) async {
        isLoading = true
        do {
            try await adminService.removeFeaturedVideo(active)
        } catch {
            print("❌ Error removing featured video: \(error)")
        }
        isLoading = false
        await adminService.loadActiveFeatured()
    }
}

// MARK: - Featured Request Row
struct FeaturedRequestRow: View {
    let request: FeaturedVideoRequest
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Thumbnail
                AppAsyncImage(url: URL(string: request.videoThumbnail)) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.videoTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("by \(request.creatorName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Duration & Price
                    HStack(spacing: 8) {
                        Label(request.requestedDuration.displayName, systemImage: "clock")
                            .font(.caption)
                        
                        Text("$\(String(format: "%.2f", request.amountPaid))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    onApprove()
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button {
                    onReject()
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Active Featured Row
struct ActiveFeaturedRow: View {
    let activeFeatured: ActiveFeaturedVideo
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AppAsyncImage(url: URL(string: activeFeatured.videoThumbnail)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activeFeatured.videoTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("by \(activeFeatured.creatorName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Expiration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Expires: \(activeFeatured.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Approval Sheet
struct ApprovalSheetView: View {
    let request: FeaturedVideoRequest
    let onAction: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Approve Featured Video?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This video will be featured for \(request.requestedDuration.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onAction(false)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Approve") {
                        onAction(true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Approve Request")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Rejection Sheet
struct RejectionSheetView: View {
    let request: FeaturedVideoRequest
    @Binding var reason: String
    let onAction: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rejection Reason") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button("Cancel") {
                        onAction(false)
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Reject Request") {
                        onAction(true)
                    }
                    .foregroundColor(.red)
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Reject Request")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Extensions
// FeaturedVideoRequest and ActiveFeaturedVideo already conform to Identifiable in their model definitions

