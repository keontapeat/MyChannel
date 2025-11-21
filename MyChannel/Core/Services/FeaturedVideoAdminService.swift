//
//  FeaturedVideoAdminService.swift
//  MyChannel
//
//  Admin service for managing featured video requests and active featured videos
//

import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FeaturedVideoAdminService: ObservableObject {
    static let shared = FeaturedVideoAdminService()
    
    @Published var pendingRequests: [FeaturedVideoRequest] = []
    @Published var activeFeaturedVideos: [ActiveFeaturedVideo] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var requestsListener: ListenerRegistration?
    private var activeListener: ListenerRegistration?
    #endif
    
    private init() {
        Task {
            await loadPendingRequests()
            await loadActiveFeatured()
            startListening()
        }
    }
    
    // MARK: - Load Data
    func loadPendingRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("featured_video_requests")
                .whereField("status", in: ["pending", "approved"])
                .order(by: "paidAt", descending: true)
                .getDocuments()
            
            pendingRequests = snap.documents.compactMap { doc in
                try? self.decodeRequest(from: doc.data(), id: doc.documentID)
            }
        } catch {
            lastError = error.localizedDescription
            print("❌ Error loading pending requests: \(error)")
        }
        #endif
    }
    
    func loadActiveFeatured() async {
        #if canImport(FirebaseFirestore)
        do {
            let now = Timestamp(date: Date())
            let snap = try await db.collection("active_featured_videos")
                .whereField("isActive", isEqualTo: true)
                .whereField("expiresAt", isGreaterThan: now)
                .order(by: "priority", descending: true)
                .order(by: "featuredAt", descending: true)
                .getDocuments()
            
            activeFeaturedVideos = snap.documents.compactMap { doc in
                try? self.decodeActiveFeatured(from: doc.data(), id: doc.documentID)
            }
        } catch {
            lastError = error.localizedDescription
            print("❌ Error loading active featured: \(error)")
        }
        #endif
    }
    
    // MARK: - Approve Request
    func approveRequest(_ request: FeaturedVideoRequest, adminUserId: String) async throws {
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        
        // Update request status
        let requestRef = db.collection("featured_video_requests").document(request.id)
        batch.updateData([
            "status": "active",
            "reviewedBy": adminUserId,
            "reviewedAt": FieldValue.serverTimestamp(),
            "featuredAt": FieldValue.serverTimestamp(),
            "isActive": true,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: requestRef)
        
        // Create active featured video
        let now = Date()
        let activeFeatured = ActiveFeaturedVideo(
            id: UUID().uuidString,
            videoId: request.videoId,
            requestId: request.id,
            creatorId: request.creatorId,
            videoTitle: request.videoTitle,
            videoThumbnail: request.videoThumbnail,
            creatorName: request.creatorName,
            featuredAt: now,
            expiresAt: request.expiresAt ?? Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now,
            priority: activeFeaturedVideos.count, // Assign priority based on current count
            isActive: true,
            createdAt: now,
            updatedAt: now
        )
        
        let activeRef = db.collection("active_featured_videos").document(activeFeatured.id)
        batch.setData([
            "id": activeFeatured.id,
            "videoId": activeFeatured.videoId,
            "requestId": activeFeatured.requestId,
            "creatorId": activeFeatured.creatorId,
            "videoTitle": activeFeatured.videoTitle,
            "videoThumbnail": activeFeatured.videoThumbnail,
            "creatorName": activeFeatured.creatorName,
            "featuredAt": Timestamp(date: activeFeatured.featuredAt),
            "expiresAt": Timestamp(date: activeFeatured.expiresAt),
            "priority": activeFeatured.priority,
            "isActive": activeFeatured.isActive,
            "createdAt": Timestamp(date: activeFeatured.createdAt),
            "updatedAt": Timestamp(date: activeFeatured.updatedAt)
        ], forDocument: activeRef)
        
        try await batch.commit()
        
        // Sync to local FeaturedStore
        await syncActiveFeaturedToLocalStore()
        #endif
    }
    
    // MARK: - Reject Request
    func rejectRequest(_ request: FeaturedVideoRequest, adminUserId: String, reason: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("featured_video_requests").document(request.id)
        try await ref.updateData([
            "status": "rejected",
            "reviewedBy": adminUserId,
            "reviewedAt": FieldValue.serverTimestamp(),
            "rejectionReason": reason,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    // MARK: - Remove Featured Video
    func removeFeaturedVideo(_ activeFeatured: ActiveFeaturedVideo) async throws {
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        
        // Deactivate active featured
        let activeRef = db.collection("active_featured_videos").document(activeFeatured.id)
        batch.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: activeRef)
        
        // Update request status
        let requestRef = db.collection("featured_video_requests").document(activeFeatured.requestId)
        batch.updateData([
            "status": "expired",
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: requestRef)
        
        try await batch.commit()
        
        // Sync to local FeaturedStore
        await syncActiveFeaturedToLocalStore()
        #endif
    }
    
    // MARK: - Update Priority
    func updatePriority(_ activeFeatured: ActiveFeaturedVideo, newPriority: Int) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("active_featured_videos").document(activeFeatured.id)
        try await ref.updateData([
            "priority": newPriority,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    // MARK: - Sync to Local Store
    private func syncActiveFeaturedToLocalStore() async {
        await loadActiveFeatured()
        
        // Get video details for active featured
        var videosToFeature: [String] = []
        for active in activeFeaturedVideos {
            videosToFeature.append(active.videoId)
        }
        
        // Note: This requires fetching full video objects from Firestore
        // For now, we'll rely on the FeaturedStore being updated manually or via another service
    }
    
    // MARK: - Listen for Changes
    private func startListening() {
        #if canImport(FirebaseFirestore)
        // Listen for pending requests
        requestsListener = db.collection("featured_video_requests")
            .whereField("status", in: ["pending", "approved"])
            .addSnapshotListener { [weak self] snap, error in
                guard let self = self else { return }
                if let error = error {
                    self.lastError = error.localizedDescription
                    return
                }
                Task { @MainActor in
                    await self.loadPendingRequests()
                }
            }
        
        // Listen for active featured videos
        activeListener = db.collection("active_featured_videos")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snap, error in
                guard let self = self else { return }
                if let error = error {
                    self.lastError = error.localizedDescription
                    return
                }
                Task { @MainActor in
                    await self.loadActiveFeatured()
                }
            }
        #endif
    }
    
    deinit {
        #if canImport(FirebaseFirestore)
        requestsListener?.remove()
        activeListener?.remove()
        #endif
    }
    
    // MARK: - Decode Helpers
    private func decodeRequest(from data: [String: Any], id: String) throws -> FeaturedVideoRequest {
        guard let videoId = data["videoId"] as? String,
              let creatorId = data["creatorId"] as? String,
              let videoTitle = data["videoTitle"] as? String,
              let videoThumbnail = data["videoThumbnail"] as? String,
              let creatorName = data["creatorName"] as? String,
              let durationRaw = data["requestedDuration"] as? String,
              let duration = FeaturedVideoRequest.FeaturedDuration(rawValue: durationRaw),
              let amountPaid = data["amountPaid"] as? Double,
              let transactionId = data["paymentTransactionId"] as? String,
              let paymentStatusRaw = data["paymentStatus"] as? String,
              let paymentStatus = FeaturedVideoRequest.PaymentStatus(rawValue: paymentStatusRaw),
              let statusRaw = data["status"] as? String,
              let status = FeaturedVideoRequest.RequestStatus(rawValue: statusRaw),
              let paidAtTimestamp = data["paidAt"] as? Timestamp,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw NSError(domain: "FeaturedVideoAdminService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid request data"])
        }
        
        let paidAt = paidAtTimestamp.dateValue()
        let createdAt = createdAtTimestamp.dateValue()
        let updatedAt = updatedAtTimestamp.dateValue()
        let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue()
        let featuredAt = (data["featuredAt"] as? Timestamp)?.dateValue()
        let reviewedAt = (data["reviewedAt"] as? Timestamp)?.dateValue()
        
        return FeaturedVideoRequest(
            id: id,
            videoId: videoId,
            creatorId: creatorId,
            videoTitle: videoTitle,
            videoThumbnail: videoThumbnail,
            creatorName: creatorName,
            requestedDuration: duration,
            amountPaid: amountPaid,
            paymentTransactionId: transactionId,
            paymentStatus: paymentStatus,
            paidAt: paidAt,
            status: status,
            reviewedBy: data["reviewedBy"] as? String,
            reviewedAt: reviewedAt,
            rejectionReason: data["rejectionReason"] as? String,
            featuredAt: featuredAt,
            expiresAt: expiresAt,
            isActive: data["isActive"] as? Bool ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func decodeActiveFeatured(from data: [String: Any], id: String) throws -> ActiveFeaturedVideo {
        guard let videoId = data["videoId"] as? String,
              let requestId = data["requestId"] as? String,
              let creatorId = data["creatorId"] as? String,
              let videoTitle = data["videoTitle"] as? String,
              let videoThumbnail = data["videoThumbnail"] as? String,
              let creatorName = data["creatorName"] as? String,
              let featuredAtTimestamp = data["featuredAt"] as? Timestamp,
              let expiresAtTimestamp = data["expiresAt"] as? Timestamp,
              let priority = data["priority"] as? Int,
              let isActive = data["isActive"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw NSError(domain: "FeaturedVideoAdminService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid active featured data"])
        }
        
        return ActiveFeaturedVideo(
            id: id,
            videoId: videoId,
            requestId: requestId,
            creatorId: creatorId,
            videoTitle: videoTitle,
            videoThumbnail: videoThumbnail,
            creatorName: creatorName,
            featuredAt: featuredAtTimestamp.dateValue(),
            expiresAt: expiresAtTimestamp.dateValue(),
            priority: priority,
            isActive: isActive,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}











