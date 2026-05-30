import Foundation
import CryptoKit

/// Phase 24: End-to-End Encryption (E2EE) for Private Content
/// Provides symmetric encryption using AES-GCM for private video streams and keys.
final class CryptoManager {
    static let shared = CryptoManager()
    
    private init() {}
    
    /// Generates a new random symmetric key for encrypting a video.
    func generateVideoEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Encrypts data (e.g. video chunks or metadata) using AES-GCM.
    func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combinedData = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combinedData
    }
    
    /// Decrypts data using AES-GCM.
    func decryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return decryptedData
    }
    
    enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
    }
}
