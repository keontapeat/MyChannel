import Foundation
import MultipeerConnectivity
import Combine

/// Phase 40: Peer-to-Peer Video Streaming
/// Integrates MultipeerConnectivity for zero-bandwidth local video sharing.
@MainActor
final class P2PVideoEngine: NSObject, ObservableObject {
    static let shared = P2PVideoEngine()
    
    private let serviceType = "mychannel-p2p"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    
    // For tracking incoming stream from a peer
    @Published var incomingStreamURL: URL?
    
    override private init() {
        super.init()
        setupP2P()
    }
    
    private func setupP2P() {
        let displayName = UIDevice.current.name
        peerID = MCPeerID(displayName: displayName)
        
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
    }
    
    func startHosting() {
        advertiser.startAdvertisingPeer()
        print("🌐 [P2P] Started advertising for P2P sharing.")
    }
    
    func stopHosting() {
        advertiser.stopAdvertisingPeer()
    }
    
    func startBrowsing() {
        browser.startBrowsingForPeers()
        print("🌐 [P2P] Started browsing for peers.")
    }
    
    func stopBrowsing() {
        browser.stopBrowsingForPeers()
    }
    
    func invitePeer(_ peer: MCPeerID) {
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }
    
    /// Streams a local video file to a connected peer
    func streamVideo(localURL: URL, to peer: MCPeerID) {
        do {
            let streamName = "video_stream_\(UUID().uuidString)"
            let outputStream = try session.startStream(withName: streamName, toPeer: peer)
            
            // In a real implementation, you would write chunks of the video data into the outputStream.
            // This requires an `NSOutputStream` and file chunking logic.
            print("🌐 [P2P] Opened stream to \(peer.displayName)")
            
            // Simulating transmission
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: localURL) {
                    let bytesWritten = data.withUnsafeBytes { buffer in
                        guard let ptr = buffer.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                        return outputStream.write(ptr, maxLength: data.count)
                    }
                    print("🌐 [P2P] Streamed \(bytesWritten) bytes to \(peer.displayName)")
                }
                outputStream.close()
            }
        } catch {
            print("⚠️ [P2P] Failed to start stream: \(error)")
        }
    }
}

extension P2PVideoEngine: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            print("🌐 [P2P] Peer \(peerID.displayName) state changed to: \(state.rawValue)")
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle metadata or command packets
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle incoming video stream
        print("🌐 [P2P] Receiving stream \(streamName) from \(peerID.displayName)")
        
        // In a real app, you would read from `stream` into a local buffer/file and feed it to AVPlayer.
    }
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}

extension P2PVideoEngine: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept for demo purposes
        Task { @MainActor in
            print("🌐 [P2P] Accepted invitation from \(peerID.displayName)")
            invitationHandler(true, self.session)
        }
    }
}

extension P2PVideoEngine: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if !self.availablePeers.contains(peerID) {
                self.availablePeers.append(peerID)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.availablePeers.removeAll { $0 == peerID }
        }
    }
}
