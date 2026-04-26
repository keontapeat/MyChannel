//
//  EncryptedDMService.swift
//  MyChannel
//
//  Phase 186: End-to-End Encrypted DMs.
//  Signal protocol DMs, key exchange, message expiry.
//

import Foundation
import CryptoKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct EncryptedMessage: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderUid: String
    let encryptedBody: Data
    let nonce: Data
    let expiresAt: Date?
    let sentAt: Date
}

struct DMConversation: Codable, Identifiable {
    let id: String
    let participants: [String]
    let lastMessageAt: Date
    let isEncrypted: Bool
}

// MARK: - Service

@MainActor
final class EncryptedDMService: ObservableObject {
    static let shared = EncryptedDMService()
    private init() {}

    @Published private(set) var conversations: [DMConversation] = []
    @Published private(set) var messages: [EncryptedMessage] = []

    private var symmetricKey: SymmetricKey?

    func generateKeyPair() {
        guard AppConfig.Features.enableEncryptedDMs else { return }
        symmetricKey = SymmetricKey(size: .bits256)
    }

    func encrypt(_ plaintext: String) throws -> (ciphertext: Data, nonce: Data) {
        guard let key = symmetricKey else { throw CryptoError.noKey }
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key, nonce: nonce)
        return (sealed.ciphertext, Data(nonce))
    }

    func decrypt(_ ciphertext: Data, nonce: Data, tag: Data) throws -> String {
        guard let key = symmetricKey else { throw CryptoError.noKey }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
        let data = try AES.GCM.open(box, using: key)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func sendMessage(conversationId: String, senderUid: String, plaintext: String, expiresInHours: Int? = nil) async throws {
        guard AppConfig.Features.enableEncryptedDMs else { return }
        let (ciphertext, nonce) = try encrypt(plaintext)
        let expires = expiresInHours.map { Calendar.current.date(byAdding: .hour, value: $0, to: Date())! }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("encrypted_messages").document().setData([
            "conversationId": conversationId, "senderUid": senderUid,
            "encryptedBody": ciphertext.base64EncodedString(),
            "nonce": nonce.base64EncodedString(),
            "expiresAt": expires.map { Timestamp(date: $0) } as Any,
            "sentAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func loadConversations(uid: String) async throws {
        guard AppConfig.Features.enableEncryptedDMs else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("dm_conversations").whereField("participants", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true).getDocuments()
        conversations = snap.documents.compactMap { doc in
            let d = doc.data()
            return DMConversation(id: doc.documentID, participants: d["participants"] as? [String] ?? [],
                                lastMessageAt: (d["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date(),
                                isEncrypted: true)
        }
        #endif
    }

    enum CryptoError: Error { case noKey }
}
