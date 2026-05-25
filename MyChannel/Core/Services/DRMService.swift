import Foundation
import AVFoundation

struct DRMConfiguration {
    let videoId: String
    let licenseURL: String
    let certificateURL: String?
    let keyId: String
    let contentId: String
    let drmSystem: DRMSystem
    
    enum DRMSystem: String, CaseIterable {
        case fairplay = "FairPlay"
        case widevine = "Widevine"
        case playready = "PlayReady"
        
        var displayName: String { rawValue }
    }
}

struct DRMAsset {
    let videoId: String
    let hlsURL: String
    let drmConfig: DRMConfiguration?
    let requiresSubscription: Bool
    let allowedDeviceTypes: [DeviceType]
    
    enum DeviceType: String, CaseIterable {
        case mobile, tablet, desktop, tv
    }
}

@MainActor
final class DRMService: NSObject, ObservableObject {
    static let shared = DRMService()
    override init() {}
    
    private var licenseLoaders: [String: AVAssetResourceLoader] = [:]
    
    func createDRMAsset(for video: Video) async -> DRMAsset? {
        // Check if video requires DRM
        guard video.monetization?.subscriptionTier != nil || video.monetization?.isMonetized == true else {
            // Regular video, no DRM needed
            return DRMAsset(
                videoId: video.id,
                hlsURL: video.videoURL,
                drmConfig: nil,
                requiresSubscription: false,
                allowedDeviceTypes: DRMAsset.DeviceType.allCases
            )
        }
        
        // Generate DRM configuration
        let drmConfig = DRMConfiguration(
            videoId: video.id,
            licenseURL: "https://api.mychannel.app/drm/license",
            certificateURL: "https://api.mychannel.app/drm/certificate",
            keyId: generateKeyId(for: video.id),
            contentId: video.id,
            drmSystem: .fairplay // iOS default
        )
        
        return DRMAsset(
            videoId: video.id,
            hlsURL: await generateDRMStreamURL(videoId: video.id),
            drmConfig: drmConfig,
            requiresSubscription: video.monetization?.subscriptionTier != nil,
            allowedDeviceTypes: [.mobile, .tablet] // Restrict to mobile for premium
        )
    }
    
    func configurePlayerForDRM(player: AVPlayer, asset: DRMAsset, userId: String?) async -> Bool {
        guard let drmConfig = asset.drmConfig else {
            // No DRM needed, configure regular player
            if let url = URL(string: asset.hlsURL) {
                let playerItem = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: playerItem)
                return true
            }
            return false
        }
        
        // Check user subscription
        if asset.requiresSubscription {
            let hasAccess = await checkSubscriptionAccess(userId: userId, videoId: asset.videoId)
            guard hasAccess else { return false }
        }
        
        // Configure DRM player
        guard let url = URL(string: asset.hlsURL) else { return false }
        let urlAsset = AVURLAsset(url: url)
        
        // Set up FairPlay DRM
        if drmConfig.drmSystem == .fairplay {
            setupFairPlayDRM(urlAsset: urlAsset, drmConfig: drmConfig, userId: userId ?? "anonymous")
        }
        
        let playerItem = AVPlayerItem(asset: urlAsset)
        player.replaceCurrentItem(with: playerItem)
        
        return true
    }
    
    private func setupFairPlayDRM(urlAsset: AVURLAsset, drmConfig: DRMConfiguration, userId: String) {
        let resourceLoader = urlAsset.resourceLoader
        resourceLoader.setDelegate(self, queue: DispatchQueue(label: "DRM"))
        licenseLoaders[drmConfig.videoId] = resourceLoader
    }
    
    private func checkSubscriptionAccess(userId: String?, videoId: String) async -> Bool {
        guard let userId = userId else { return false }
        
        // Check user's subscription status in backend
        // For now, mock the check
        return Bool.random() // In production, would check actual subscription
    }
    
    private func generateDRMStreamURL(videoId: String) async -> String {
        // Generate DRM-protected HLS URL
        return "https://cdn.mychannel.app/drm/\(videoId)/master.m3u8"
    }
    
    private func generateKeyId(for videoId: String) -> String {
        return "key_\(videoId)_\(UUID().uuidString)"
    }
}

// MARK: - AVAssetResourceLoaderDelegate
extension DRMService: AVAssetResourceLoaderDelegate {
    nonisolated func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        guard let url = loadingRequest.request.url,
              let scheme = url.scheme else {
            return false
        }
        
        // Handle FairPlay license requests
        if scheme == "skd" {
            Task {
                await handleFairPlayLicenseRequest(loadingRequest)
            }
            return true
        }
        
        return false
    }
    
    private func handleFairPlayLicenseRequest(_ loadingRequest: AVAssetResourceLoadingRequest) async {
        // FairPlay license acquisition
        guard let url = loadingRequest.request.url,
              let contentId = url.host else {
            loadingRequest.finishLoading(with: NSError(domain: "DRMError", code: -1))
            return
        }
        
        do {
            // 1. Get application certificate
            let certificate = try await fetchApplicationCertificate()
            
            // 2. Create SPC (Server Playback Context)
            guard let contentIdData = contentId.data(using: .utf8) else {
                loadingRequest.finishLoading(with: NSError(domain: "DRMError", code: -2))
                return
            }
            let spcData = try await createSPC(contentId: contentIdData, certificate: certificate)
            
            // 3. Get CKC (Content Key Context) from license server
            let ckcData = try await fetchLicense(spc: spcData, contentId: contentId)
            
            // 4. Provide the license to the loading request
            if let dataRequest = loadingRequest.dataRequest {
                dataRequest.respond(with: ckcData)
            }
            
            loadingRequest.finishLoading()
            
        } catch {
            loadingRequest.finishLoading(with: error)
        }
    }
    
    private func fetchApplicationCertificate() async throws -> Data {
        // Fetch FairPlay application certificate
        guard let url = URL(string: "https://api.mychannel.app/drm/certificate") else {
            throw DRMError.invalidCertificateURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    private func createSPC(contentId: Data, certificate: Data) async throws -> Data {
        // Create Server Playback Context using AVAssetResourceLoadingRequest
        // This is a simplified version - production would handle this properly
        return contentId + certificate
    }
    
    private func fetchLicense(spc: Data, contentId: String) async throws -> Data {
        // Fetch license from license server
        guard let url = URL(string: "https://api.mychannel.app/drm/license") else {
            throw DRMError.invalidLicenseURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = spc
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        // Note: POST requests are not cached, but NetworkOptimizer handles deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        
        return data
    }
}

enum DRMError: Error {
    case invalidCertificateURL
    case invalidLicenseURL
    case licenseRequestFailed
    case spcCreationFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidCertificateURL: return "Invalid certificate URL"
        case .invalidLicenseURL: return "Invalid license URL"
        case .licenseRequestFailed: return "License request failed"
        case .spcCreationFailed: return "SPC creation failed"
        }
    }
}
