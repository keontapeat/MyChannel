//
//  UserCollectionsFirestoreService.swift
//  MyChannel
//
//  Syncs watch later, likes, subscriptions with Firestore under users/{uid}/collections/*
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UserCollectionsFirestoreService: ObservableObject {
    static let shared = UserCollectionsFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    func toggleWatchLater(userId: String, videoId: String, add: Bool) async {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("users").document(userId).collection("watchLater").document(videoId)
        do {
            if add {
                try await ref.setData(["addedAt": FieldValue.serverTimestamp()])
            } else {
                try await ref.delete()
            }
        } catch { print("watchLater sync error: \(error)") }
        #endif
    }

    func toggleSubscription(userId: String, creatorId: String, add: Bool) async {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("users").document(userId).collection("subscriptions").document(creatorId)
        do {
            if add {
                try await ref.setData(["subscribedAt": FieldValue.serverTimestamp()])
            } else {
                try await ref.delete()
            }
        } catch { print("subscription sync error: \(error)") }
        #endif
    }

    func fetchWatchLater(userId: String) async -> Set<String> {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("users").document(userId).collection("watchLater").getDocuments()
            return Set(snap.documents.map { $0.documentID })
        } catch {
            print("fetchWatchLater error: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    func fetchSubscriptions(userId: String) async -> Set<String> {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("users").document(userId).collection("subscriptions").getDocuments()
            return Set(snap.documents.map { $0.documentID })
        } catch {
            print("fetchSubscriptions error: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    func listen(userId: String,
                onWatchLaterChanged: @escaping (Set<String>) -> Void,
                onSubscriptionsChanged: @escaping (Set<String>) -> Void) -> Any {
        #if canImport(FirebaseFirestore)
        let wl = db.collection("users").document(userId).collection("watchLater")
        let subs = db.collection("users").document(userId).collection("subscriptions")
        let wlListener = wl.addSnapshotListener { snap, _ in
            guard let snap = snap else { return }
            onWatchLaterChanged(Set(snap.documents.map { $0.documentID }))
        }
        let subsListener = subs.addSnapshotListener { snap, _ in
            guard let snap = snap else { return }
            onSubscriptionsChanged(Set(snap.documents.map { $0.documentID }))
        }
        // Return a combined listener handle as a tuple to retain references
        return (wlListener, subsListener)
        #else
        return ()
        #endif
    }
}


