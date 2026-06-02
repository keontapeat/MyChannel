import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UserLookupService: ObservableObject {
    static let shared = UserLookupService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    func resolveUser(usernameOrDisplayName: String, fallback: User? = nil) async -> User? {
        let normalized = usernameOrDisplayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()

        if let fallback,
           fallback.username.lowercased() == normalized || fallback.displayName.lowercased() == normalized {
            return fallback
        }

        #if canImport(FirebaseFirestore)
        do {
            let usernameSnap = try await db.collection("users")
                .whereField("username", isEqualTo: normalized)
                .limit(to: 1)
                .getDocuments()
            if let doc = usernameSnap.documents.first {
                return mapUser(id: doc.documentID, data: doc.data())
            }

            let displaySnap = try await db.collection("users")
                .whereField("displayNameLowercased", isEqualTo: normalized)
                .limit(to: 1)
                .getDocuments()
            if let doc = displaySnap.documents.first {
                return mapUser(id: doc.documentID, data: doc.data())
            }
        } catch {
            print("⚠️ [UserLookupService] Failed resolving user \(normalized): \(error)")
        }
        #endif

        return fallback
    }

    #if canImport(FirebaseFirestore)
    private func mapUser(id: String, data: [String: Any]) -> User {
        User(
            id: id,
            username: data["username"] as? String ?? "user",
            displayName: data["displayName"] as? String ?? data["username"] as? String ?? "Creator",
            email: data["email"] as? String ?? "",
            profileImageURL: data["profileImageURL"] as? String ?? data["profileImageUrl"] as? String,
            bannerImageURL: data["bannerImageURL"] as? String ?? data["bannerImageUrl"] as? String,
            bio: data["bio"] as? String,
            subscriberCount: data["subscriberCount"] as? Int ?? 0,
            videoCount: data["videoCount"] as? Int ?? 0,
            isVerified: data["isVerified"] as? Bool ?? false,
            isCreator: true,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    #endif
}

// MARK: - Batched ID Resolution (Championship / Leaderboards)

extension UserLookupService {
    /// Resolve many users by their document ID in one pass.
    /// Firestore `in` queries cap at 10 IDs, so we chunk and run in parallel.
    /// Returns a `[userId: User]` map; unknown IDs are simply omitted.
    func resolveUsersByIds(_ ids: [String]) async -> [String: User] {
        let uniqueIds = Array(Set(ids.filter { !$0.isEmpty && $0 != "BYE" && $0 != "TBD" }))
        guard !uniqueIds.isEmpty else { return [:] }

        #if canImport(FirebaseFirestore)
        var result: [String: User] = [:]
        let chunks = stride(from: 0, to: uniqueIds.count, by: 10).map {
            Array(uniqueIds[$0..<min($0 + 10, uniqueIds.count)])
        }

        await withTaskGroup(of: [String: User].self) { group in
            for chunk in chunks {
                group.addTask { [weak self] in
                    guard let self else { return [:] }
                    return await self.fetchChunk(chunk)
                }
            }
            for await partial in group {
                result.merge(partial) { _, new in new }
            }
        }
        return result
        #else
        return [:]
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func fetchChunk(_ ids: [String]) async -> [String: User] {
        do {
            let snap = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: ids)
                .getDocuments()
            var map: [String: User] = [:]
            for doc in snap.documents {
                map[doc.documentID] = mapUser(id: doc.documentID, data: doc.data())
            }
            return map
        } catch {
            print("⚠️ [UserLookupService] resolveUsersByIds chunk failed: \(error)")
            return [:]
        }
    }
    #endif
}
