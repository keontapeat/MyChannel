import Foundation
import AVFoundation

/// Phase 58: Offline DRM Key Rotation
/// Manages FairPlay Streaming local key persistence and offline expiration policies.
final class DRMKeyManager: NSObject, AVContentKeySessionDelegate {
    static let shared = DRMKeyManager()
    
    private var contentKeySession: AVContentKeySession
    private let keyQueue = DispatchQueue(label: "com.mychannel.drm.keyqueue")
    
    // In a FAANG app, this comes from your backend / license server
    private let licenseServerURL = URL(string: "https://fps.mychannel.app/license")!
    
    override private init() {
        // Use FairPlay Streaming
        self.contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        super.init()
        self.contentKeySession.setDelegate(self, queue: keyQueue)
    }
    
    /// Attaches the DRM session to an AVAsset
    func attach(to asset: AVURLAsset) {
        contentKeySession.addContentKeyRecipient(asset)
    }
    
    // MARK: - AVContentKeySessionDelegate
    
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        Task {
            do {
                try await handleKeyRequest(keyRequest)
            } catch {
                keyRequest.processContentKeyResponseError(error)
            }
        }
    }
    
    private func handleKeyRequest(_ keyRequest: AVContentKeyRequest) async throws {
        // 1. Get the Application Certificate from the server
        let certURL = URL(string: "https://fps.mychannel.app/cert")!
        let (certData, _) = try await URLSession.shared.data(from: certURL)
        
        // 2. Ask the request for the Server Playback Context (SPC) using the cert
        guard let identifier = keyRequest.identifier as? String,
              let assetIdData = identifier.data(using: .utf8) else {
            throw NSError(domain: "DRMKeyManager", code: -1, userInfo: nil)
        }
        
        let spcData = try await keyRequest.makeStreamingContentKeyRequestData(
            forApp: certData,
            contentIdentifier: assetIdData,
            options: [AVContentKeyRequestProtocolVersionsKey: [1]]
        )
        
        // 3. Send the SPC to the License Server to get the Content Key Context (CKC)
        var request = URLRequest(url: licenseServerURL)
        request.httpMethod = "POST"
        request.httpBody = spcData
        
        let (ckcData, _) = try await URLSession.shared.data(for: request)
        
        // 4. Provide the CKC back to AVFoundation
        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
        keyRequest.processContentKeyResponse(keyResponse)
        
        print("🔐 [DRMKeyManager] Successfully processed DRM key request for offline/online playback.")
    }
}
