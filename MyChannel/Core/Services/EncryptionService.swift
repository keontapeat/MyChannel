#if canImport(CryptoSwift)
import CryptoSwift
#endif
import Foundation
import CryptoKit

/// Client-side encryption for DRM tokens, media keys, and sensitive payloads.
final class EncryptionService {
    static let shared = EncryptionService()
    private init() {}

    // MARK: - AES-256 GCM (CryptoSwift)

    func encryptAES(data: Data, key: Data) throws -> Data {
        #if canImport(CryptoSwift)
        let iv = AES.randomIV(AES.blockSize)
        let aes = try AES(key: Array(key), blockMode: GCM(iv: iv, mode: .combined), padding: .noPadding)
        let encrypted = try aes.encrypt(Array(data))
        var result = Data(iv)
        result.append(Data(encrypted))
        return result
        #else
        throw EncryptionError.unavailable
        #endif
    }

    func decryptAES(data: Data, key: Data) throws -> Data {
        #if canImport(CryptoSwift)
        guard data.count > AES.blockSize else { throw EncryptionError.invalidData }
        let iv = Array(data.prefix(AES.blockSize))
        let ciphertext = Array(data.suffix(from: AES.blockSize))
        let aes = try AES(key: Array(key), blockMode: GCM(iv: iv, mode: .combined), padding: .noPadding)
        let decrypted = try aes.decrypt(ciphertext)
        return Data(decrypted)
        #else
        throw EncryptionError.unavailable
        #endif
    }

    // MARK: - HMAC-SHA256 signature

    func hmacSHA256(data: Data, key: Data) -> String {
        #if canImport(CryptoSwift)
        let hmac = try? HMAC(key: Array(key), variant: .sha2(.sha256)).authenticate(Array(data))
        return hmac?.toHexString() ?? ""
        #else
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
        #endif
    }

    // MARK: - Key derivation

    func deriveKey(from password: String, salt: Data, keyLength: Int = 32) -> Data {
        #if canImport(CryptoSwift)
        let pbkdf2 = try? PKCS5.PBKDF2(password: Array(password.utf8),
                                         salt: Array(salt),
                                         iterations: 100_000,
                                         keyLength: keyLength,
                                         variant: .sha2(.sha256)).calculate()
        return Data(pbkdf2 ?? [])
        #else
        return Data(SHA256.hash(data: Data(password.utf8) + salt))
        #endif
    }

    // MARK: - Random key generation

    func generateKey(length: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
    }

    enum EncryptionError: Error {
        case unavailable
        case invalidData
    }
}
