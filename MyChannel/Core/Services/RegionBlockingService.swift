import Foundation
import Network
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct RegionPolicy: Codable {
    let videoId: String
    let allowedRegions: [String]
    let blockedRegions: [String]
    let requiresLicense: [String] // Regions requiring broadcast license
    let createdAt: Date
    let updatedBy: String?
}

struct UserGeolocation: Codable {
    let userId: String?
    let ipAddress: String
    let countryCode: String
    let regionCode: String?
    let city: String?
    let timezone: String
    let vpnDetected: Bool
    let lastUpdated: Date
}

@MainActor
final class RegionBlockingService: ObservableObject {
    static let shared = RegionBlockingService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private let monitor = NWPathMonitor()
    @Published var currentRegion: String = "US"
    @Published var isVPNDetected: Bool = false
    
    func detectUserLocation() async -> UserGeolocation? {
        // Get user's IP and location
        do {
            guard let url = URL(string: "https://ipapi.co/json/") else { return nil }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(IPAPIResponse.self, from: data)
            
            // Basic VPN detection
            let vpnDetected = await detectVPN(ip: response.ip)
            
            let geolocation = UserGeolocation(
                userId: AppState.shared.currentUser?.id,
                ipAddress: response.ip,
                countryCode: response.countryCode,
                regionCode: response.region,
                city: response.city,
                timezone: response.timezone,
                vpnDetected: vpnDetected,
                lastUpdated: Date()
            )
            
            await MainActor.run {
                self.currentRegion = response.countryCode
                self.isVPNDetected = vpnDetected
            }
            
            return geolocation
        } catch {
            // Fallback to default US region
            return UserGeolocation(
                userId: AppState.shared.currentUser?.id,
                ipAddress: "0.0.0.0",
                countryCode: "US",
                regionCode: nil,
                city: nil,
                timezone: "America/New_York",
                vpnDetected: false,
                lastUpdated: Date()
            )
        }
    }
    
    func checkContentAccess(videoId: String, userLocation: UserGeolocation) async -> ContentAccessResult {
        // Get region policy for video
        guard let policy = await getRegionPolicy(videoId: videoId) else {
            return .allowed // No restrictions
        }
        
        let userRegion = userLocation.countryCode
        
        // Check if region is explicitly blocked
        if policy.blockedRegions.contains(userRegion) {
            return .blockedInRegion(reason: "Content not available in your region")
        }
        
        // Check if region is explicitly allowed (whitelist mode)
        if !policy.allowedRegions.isEmpty && !policy.allowedRegions.contains(userRegion) {
            return .blockedInRegion(reason: "Content only available in select regions")
        }
        
        // Check license requirements
        if policy.requiresLicense.contains(userRegion) {
            let hasLicense = await checkBroadcastLicense(videoId: videoId, region: userRegion)
            if !hasLicense {
                return .requiresLicense(reason: "Broadcast license required in \(userRegion)")
            }
        }
        
        // Check for VPN bypass attempts
        if userLocation.vpnDetected {
            return .vpnDetected(reason: "VPN detected - please disable to access geo-restricted content")
        }
        
        return .allowed
    }
    
    func setRegionPolicy(videoId: String, allowedRegions: [String], blockedRegions: [String], requiresLicense: [String], updatedBy: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            _ = RegionPolicy(
                videoId: videoId,
                allowedRegions: allowedRegions,
                blockedRegions: blockedRegions,
                requiresLicense: requiresLicense,
                createdAt: Date(),
                updatedBy: updatedBy
            ) // policy - used for Firestore storage
            
            try await db.collection("region_policies").document(videoId).setData([
                "allowedRegions": allowedRegions,
                "blockedRegions": blockedRegions,
                "requiresLicense": requiresLicense,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedBy": updatedBy
            ])
            
            // Update video document
            try await db.collection("videos").document(videoId).setData([
                "hasRegionRestrictions": !allowedRegions.isEmpty || !blockedRegions.isEmpty,
                "regionRestrictionsUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func getBulkRegionPolicies(videoIds: [String]) async -> [String: RegionPolicy] {
        var policies: [String: RegionPolicy] = [:]
        
        for videoId in videoIds {
            if let policy = await getRegionPolicy(videoId: videoId) {
                policies[videoId] = policy
            }
        }
        
        return policies
    }
    
    private func getRegionPolicy(videoId: String) async -> RegionPolicy? {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("region_policies").document(videoId).getDocument()
            guard let data = doc.data() else { return nil }
            
            return RegionPolicy(
                videoId: videoId,
                allowedRegions: data["allowedRegions"] as? [String] ?? [],
                blockedRegions: data["blockedRegions"] as? [String] ?? [],
                requiresLicense: data["requiresLicense"] as? [String] ?? [],
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                updatedBy: data["updatedBy"] as? String
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    private func checkBroadcastLicense(videoId: String, region: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("broadcast_licenses")
                .whereField("region", isEqualTo: region)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            return !doc.documents.isEmpty
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    private func detectVPN(ip: String) async -> Bool {
        // Simple VPN detection - in production would use specialized service
        do {
            guard let url = URL(string: "https://vpnapi.io/api/\(ip)?key=YOUR_VPN_API_KEY") else { return false }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(VPNResponse.self, from: data)
            return response.security.vpn || response.security.proxy
        } catch {
            return false // Default to no VPN if detection fails
        }
    }
}

struct IPAPIResponse: Codable {
    let ip: String
    let countryCode: String
    let region: String?
    let city: String?
    let timezone: String
    
    private enum CodingKeys: String, CodingKey {
        case ip
        case countryCode = "country_code"
        case region
        case city
        case timezone
    }
}

struct VPNResponse: Codable {
    let security: SecurityInfo
    
    struct SecurityInfo: Codable {
        let vpn: Bool
        let proxy: Bool
        let tor: Bool
    }
}

enum ContentAccessResult {
    case allowed
    case blockedInRegion(reason: String)
    case requiresLicense(reason: String)
    case vpnDetected(reason: String)
    case ageRestricted(reason: String)
    
    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
    
    var errorMessage: String? {
        switch self {
        case .allowed: return nil
        case .blockedInRegion(let reason): return reason
        case .requiresLicense(let reason): return reason
        case .vpnDetected(let reason): return reason
        case .ageRestricted(let reason): return reason
        }
    }
}
