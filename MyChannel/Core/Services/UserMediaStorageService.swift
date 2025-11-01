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
        guard let data = image.jpegData(compressionQuality: 0.9) else { return "" }
        let ref = storage.reference().child("user-avatars/\(uid).jpg")
        let _ = try await ref.putDataAsync(data, metadata: { let md = StorageMetadata(); md.contentType = "image/jpeg"; return md }())
        let url = try await ref.downloadURL().absoluteString
        try await db.collection("users").document(uid).updateData(["avatarUrl": url])
        return url
        #else
        return ""
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




