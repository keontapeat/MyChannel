//
//  UserMediaStorageService.swift
//  MyChannel
//
//  Uploads user avatar and banner to Firebase Storage and updates Firestore users/{uid}.
//

import Foundation
import UIKit
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UserMediaStorageService: ObservableObject {
    static let shared = UserMediaStorageService()
    private init() {}

    #if canImport(FirebaseStorage)
    private var storage: Storage { Storage.storage() }
    #endif
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    func uploadAvatar(uid: String, image: UIImage) async throws -> String {
        #if canImport(FirebaseStorage)
        print("📤 [UserMediaStorageService] Starting avatar upload for uid: \(uid)")
        
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            print("🚨 [UserMediaStorageService] Failed to convert image to JPEG data")
            throw NSError(domain: "UserMediaStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }
        
        print("📤 [UserMediaStorageService] Image data size: \(data.count) bytes")
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "user-avatars/\(uid)-\(timestamp).jpg"
        let ref = storage.reference().child(path)
        print("📤 [UserMediaStorageService] Uploading to path: \(path)")
        
        let _ = try await ref.putDataAsync(data, metadata: { let md = StorageMetadata(); md.contentType = "image/jpeg"; return md }())
        print("✅ [UserMediaStorageService] Upload to Storage successful")
        
        let url = try await ref.downloadURL().absoluteString
        print("✅ [UserMediaStorageService] Download URL obtained: \(url)")
        
        #if canImport(FirebaseFirestore)
        try? await db.collection("users").document(uid).setData([
            "profileImageURL": url,
            "profileImageUrl": url,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
        
        return url
        #else
        throw NSError(domain: "UserMediaStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }

    func uploadBanner(uid: String, image: UIImage) async throws -> String {
        #if canImport(FirebaseStorage)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "UserMediaStorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert banner image to JPEG"])
        }
        let ref = storage.reference().child("user-banners/\(uid).jpg")
        let _ = try await ref.putDataAsync(data, metadata: { let md = StorageMetadata(); md.contentType = "image/jpeg"; return md }())
        let url = try await ref.downloadURL().absoluteString
        // Must match User model + UserFirestoreService.fetchUser ("bannerImageURL"). Legacy key kept for older docs/web.
        try await db.collection("users").document(uid).setData([
            "bannerImageURL": url,
            "bannerImageUrl": url,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return url
        #else
        throw NSError(domain: "UserMediaStorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }
    
    func uploadBannerVideo(uid: String, videoURL: URL) async throws -> String {
        #if canImport(FirebaseStorage)
        print("📤 [UserMediaStorageService] Starting banner video upload for uid: \(uid)")
        
        let videoData = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: videoURL)
        }.value
        print("📤 [UserMediaStorageService] Video data size: \(videoData.count) bytes")
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "user-banner-videos/\(uid)-\(timestamp).mp4"
        let ref = storage.reference().child(path)
        print("📤 [UserMediaStorageService] Uploading video to path: \(path)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        let _ = try await ref.putDataAsync(videoData, metadata: metadata)
        print("✅ [UserMediaStorageService] Video upload to Storage successful")
        
        let url = try await ref.downloadURL().absoluteString
        print("✅ [UserMediaStorageService] Video download URL obtained: \(url)")
        
        #if canImport(FirebaseFirestore)
        try? await db.collection("users").document(uid).setData([
            "bannerVideoURL": url,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
        
        return url
        #else
        throw NSError(domain: "UserMediaStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }
    
    func deleteImage(from urlString: String) async throws {
        #if canImport(FirebaseStorage)
        print("🗑️ [UserMediaStorageService] Deleting image from Storage: \(urlString)")
        let ref = storage.reference(forURL: urlString)
        try await ref.delete()
        print("✅ [UserMediaStorageService] Image deleted from Storage")
        #else
        throw NSError(domain: "UserMediaStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }
}




