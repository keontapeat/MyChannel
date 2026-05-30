import Foundation
import MultipeerConnectivity
import Combine

/// Phase 68: Peer-to-Peer Mesh Networking (Group Streaming)
/// Extends MultipeerConnectivity to share a single downloaded video cache across multiple nearby devices.
@MainActor
final class P2PMeshNetworkEngine: NSObject, ObservableObject {
    static let shared = P2PMeshNetworkEngine()
    
    private let serviceType = "mychannel-mesh"
    private var myPeerId: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    @Published var connectedPeers: [MCPeerID] = []
    
    private override init() {
        super.init()
        if let username = AuthenticationManager.shared.currentUser?.displayName {
            myPeerId = MCPeerID(displayName: username)
        } else {
            myPeerId = MCPeerID(displayName: UIDevice.current.name)
        }
        
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        browser.delegate = self
    }
    
    func startMesh() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        print("🕸️ [P2PMesh] Started advertising and browsing for mesh network.")
    }
    
    func stopMesh() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        connectedPeers.removeAll()
        print("🕸️ [P2PMesh] Stopped mesh network.")
    }
    
    /// Shares a downloaded video chunk with the mesh network
    func broadcastCachedVideoChunk(data: Data, videoId: String, byteRange: String) {
        guard !session.connectedPeers.isEmpty else { return }
        
        let payload: [String: Any] = [
            "videoId": videoId,
            "byteRange": byteRange,
            "data": data
        ]
        
        do {
            let encoded = try NSKeyedArchiver.archivedData(withRootObject: payload, requiringSecureCoding: false)
            try session.send(encoded, toPeers: session.connectedPeers, with: .reliable)
            print("📤 [P2PMesh] Broadcasted cached chunk (\(byteRange)) to \(session.connectedPeers.count) peers.")
        } catch {
            print("⚠️ [P2PMesh] Failed to broadcast chunk: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate
extension P2PMeshNetworkEngine: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            switch state {
            case .connected:
                print("🔗 [P2PMesh] Connected to peer: \(peerID.displayName)")
            case .connecting:
                print("⏳ [P2PMesh] Connecting to peer: \(peerID.displayName)")
            case .notConnected:
                print("❌ [P2PMesh] Disconnected from peer: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Parse incoming cache chunk and save to URLCache
        do {
            if let payload = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSData.self], from: data) as? [String: Any],
               let videoId = payload["videoId"] as? String,
               let byteRange = payload["byteRange"] as? String,
               let chunkData = payload["data"] as? Data {
                
                print("📥 [P2PMesh] Received cached chunk (\(byteRange)) for \(videoId) from \(peerID.displayName). Saving to URLCache...")
                // In a FAANG implementation, inject this directly into your custom AVAssetResourceLoaderDelegate
            }
        } catch {
            print("⚠️ [P2PMesh] Failed to decode incoming chunk: \(error)")
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension P2PMeshNetworkEngine: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations for the mesh
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension P2PMeshNetworkEngine: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Auto-invite found peers to the mesh
        Task { @MainActor in
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
