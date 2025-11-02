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
        
        let ref = storage.reference().child("user-avatars/\(uid).jpg")
        print("📤 [UserMediaStorageService] Uploading to path: user-avatars/\(uid).jpg")
        
        let _ = try await ref.putDataAsync(data, metadata: { let md = StorageMetadata(); md.contentType = "image/jpeg"; return md }())
        print("✅ [UserMediaStorageService] Upload to Storage successful")
        
        let url = try await ref.downloadURL().absoluteString
        print("✅ [UserMediaStorageService] Download URL obtained: \(url)")
        
        // ⚠️ DO NOT write to Firestore here - let EditProfileView call UserFirestoreService.updateUser()
        // This prevents duplicate writes and race conditions
        // The URL will be written to Firestore when the full user profile is saved
        
        return url
        #else
        throw NSError(domain: "UserMediaStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase Storage not available"])
        #endif
    }

    func uploadBanner(uid: String, image: UIImage) async throws -> String {
        #if canImport(FirebaseStorage)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return "" }
        let ref = storage.reference().child("user-banners/\(uid).jpg")
        let _ = try await ref.putDataAsync(data, metadata: { let md = StorageMetadata(); md.contentType = "image/jpeg"; return md }())
        let url = try await ref.downloadURL().absoluteString
        try await db.collection("users").document(uid).updateData(["bannerImageUrl": url])
        return url
        #else
        return ""
        #endif
    }
}




