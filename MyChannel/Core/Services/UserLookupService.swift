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
