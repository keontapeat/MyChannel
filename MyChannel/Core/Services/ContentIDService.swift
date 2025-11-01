import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ContentMatch: Identifiable, Codable {
    let id: String
    let sourceVideoId: String
    let matchedVideoId: String
    let matchType: MatchType
    let confidence: Double
    let timeRange: MatchTimeRange
    let rightsholder: String
    let policy: MatchPolicy
    let claimId: String?
    let status: MatchStatus
    let createdAt: Date
    
    enum MatchType: String, Codable {
        case video, audio, audioVideo
    }
    
    enum MatchPolicy: String, Codable {
        case block, monetize, track, mute
        
        var displayName: String {
            switch self {
            case .block: return "Block"
            case .monetize: return "Monetize"
            case .track: return "Track"
            case .mute: return "Mute"
            }
        }
    }
    
    enum MatchStatus: String, Codable {
        case active, disputed, resolved, expired
    }
    
    struct MatchTimeRange: Codable {
        let start: TimeInterval
        let duration: TimeInterval
        let sourceStart: TimeInterval?
    }
}

struct ContentIDReference: Codable {
    let id: String
    let title: String
    let rightsholder: String
    let fingerprints: Fingerprints
    let policy: ContentMatch.MatchPolicy
    let isActive: Bool
    let uploadedAt: Date
    
    struct Fingerprints: Codable {
        let audioFingerprint: String?
        let videoFingerprint: String?
        let thumbnailFingerprint: String?
    }
}

@MainActor
final class ContentIDService: ObservableObject {
    static let shared = ContentIDService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    @Published var activeMatches: [ContentMatch] = []
    @Published var referenceFiles: [ContentIDReference] = []
    
    func scanForMatches(videoId: String, videoURL: String, audioURL: String?, thumbnailURL: String?) async -> [ContentMatch] {
        // Generate fingerprints for uploaded content
        let fingerprints = await generateFingerprints(
            videoURL: videoURL,
            audioURL: audioURL,
            thumbnailURL: thumbnailURL
        )
        
        // Search against reference database
        let matches = await searchReferences(fingerprints: fingerprints, videoId: videoId)
        
        // Store matches
        for match in matches {
            await storeMatch(match)
            
            // Apply policy automatically
            await applyMatchPolicy(match: match)
        }
        
        return matches
    }
    
    func uploadReferenceFile(title: String, rightsholder: String, videoURL: String, audioURL: String?, policy: ContentMatch.MatchPolicy) async -> String? {
        // Generate fingerprints for reference content
        let fingerprints = await generateFingerprints(videoURL: videoURL, audioURL: audioURL, thumbnailURL: nil)
        
        let reference = ContentIDReference(
            id: UUID().uuidString,
            title: title,
            rightsholder: rightsholder,
            fingerprints: ContentIDReference.Fingerprints(
                audioFingerprint: fingerprints.audio,
                videoFingerprint: fingerprints.video,
                thumbnailFingerprint: fingerprints.thumbnail
            ),
            policy: policy,
            isActive: true,
            uploadedAt: Date()
        )
        
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("content_id_references").document(reference.id).setData([
                "title": reference.title,
                "rightsholder": reference.rightsholder,
                "fingerprints": [
                    "audioFingerprint": reference.fingerprints.audioFingerprint as Any,
                    "videoFingerprint": reference.fingerprints.videoFingerprint as Any,
                    "thumbnailFingerprint": reference.fingerprints.thumbnailFingerprint as Any
                ],
                "policy": reference.policy.rawValue,
                "isActive": reference.isActive,
                "uploadedAt": FieldValue.serverTimestamp()
            ])
            return reference.id
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func disputeMatch(matchId: String, userId: String, reason: String, evidence: [String]) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            // Create dispute
            let disputeRef = db.collection("content_disputes").document()
            try await disputeRef.setData([
                "matchId": matchId,
                "disputerId": userId,
                "reason": reason,
                "evidence": evidence,
                "status": "submitted",
                "submittedAt": FieldValue.serverTimestamp()
            ])
            
            // Update match status
            try await db.collection("content_matches").document(matchId).setData([
                "status": ContentMatch.MatchStatus.disputed.rawValue,
                "disputedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Temporarily restore content pending review
            if let match = activeMatches.first(where: { $0.id == matchId }) {
                await restoreContentPendingDispute(videoId: match.matchedVideoId)
            }
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func resolveDispute(disputeId: String, resolution: DisputeResolution, reviewerId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("content_disputes").document(disputeId).setData([
                "status": resolution.rawValue,
                "resolvedAt": FieldValue.serverTimestamp(),
                "resolvedBy": reviewerId
            ], merge: true)
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    private func generateFingerprints(videoURL: String, audioURL: String?, thumbnailURL: String?) async -> (video: String?, audio: String?, thumbnail: String?) {
        // Simulate fingerprint generation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second processing time
        
        let videoHash = videoURL.isEmpty ? nil : "vfp_\(abs(videoURL.hashValue))_\(Int.random(in: 1000...9999))"
        let audioHash = audioURL?.isEmpty == false ? "afp_\(abs((audioURL ?? "").hashValue))_\(Int.random(in: 1000...9999))" : nil
        let thumbnailHash = thumbnailURL?.isEmpty == false ? "tfp_\(abs((thumbnailURL ?? "").hashValue))_\(Int.random(in: 1000...9999))" : nil
        
        return (videoHash, audioHash, thumbnailHash)
    }
    
    private func searchReferences(fingerprints: (video: String?, audio: String?, thumbnail: String?), videoId: String) async -> [ContentMatch] {
        var matches: [ContentMatch] = []
        
        #if canImport(FirebaseFirestore)
        do {
            // Search for similar fingerprints
            let refsQuery = try await db.collection("content_id_references")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            for doc in refsQuery.documents {
                let data = doc.data()
                let refFingerprints = data["fingerprints"] as? [String: String] ?? [:]
                
                // Simple similarity check (in production would use proper fingerprint matching)
                var confidence = 0.0
                var matchType: ContentMatch.MatchType = .video
                
                if let videoFP = fingerprints.video,
                   let refVideoFP = refFingerprints["videoFingerprint"],
                   similarityScore(videoFP, refVideoFP) > 0.8 {
                    confidence += 0.6
                    matchType = .video
                }
                
                if let audioFP = fingerprints.audio,
                   let refAudioFP = refFingerprints["audioFingerprint"],
                   similarityScore(audioFP, refAudioFP) > 0.8 {
                    confidence += 0.4
                    matchType = confidence > 0.6 ? .audioVideo : .audio
                }
                
                if confidence > 0.7 { // Threshold for match
                    let match = ContentMatch(
                        id: UUID().uuidString,
                        sourceVideoId: doc.documentID,
                        matchedVideoId: videoId,
                        matchType: matchType,
                        confidence: confidence,
                        timeRange: ContentMatch.MatchTimeRange(start: 0, duration: 300, sourceStart: 0), // Mock time range
                        rightsholder: data["rightsholder"] as? String ?? "",
                        policy: ContentMatch.MatchPolicy(rawValue: data["policy"] as? String ?? "track") ?? .track,
                        claimId: nil,
                        status: .active,
                        createdAt: Date()
                    )
                    matches.append(match)
                }
            }
        } catch { }
        #endif
        
        return matches
    }
    
    private func storeMatch(_ match: ContentMatch) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("content_matches").document(match.id).setData([
                "sourceVideoId": match.sourceVideoId,
                "matchedVideoId": match.matchedVideoId,
                "matchType": match.matchType.rawValue,
                "confidence": match.confidence,
                "timeRange": [
                    "start": match.timeRange.start,
                    "duration": match.timeRange.duration,
                    "sourceStart": match.timeRange.sourceStart as Any
                ],
                "rightsholder": match.rightsholder,
                "policy": match.policy.rawValue,
                "status": match.status.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
    
    private func applyMatchPolicy(match: ContentMatch) async {
        switch match.policy {
        case .block:
            await blockContent(videoId: match.matchedVideoId, reason: "Copyright match: \(match.rightsholder)")
        case .monetize:
            await shareRevenue(videoId: match.matchedVideoId, rightsholder: match.rightsholder, percentage: 0.5)
        case .mute:
            await muteAudio(videoId: match.matchedVideoId, timeRange: match.timeRange)
        case .track:
            await trackUsage(videoId: match.matchedVideoId, rightsholder: match.rightsholder)
        }
    }
    
    private func blockContent(videoId: String, reason: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("videos").document(videoId).setData([
                "visibility": "blocked",
                "blockReason": reason,
                "blockedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }
    
    private func shareRevenue(videoId: String, rightsholder: String, percentage: Double) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("revenue_sharing").document("\(videoId)_\(rightsholder)").setData([
                "videoId": videoId,
                "rightsholder": rightsholder,
                "percentage": percentage,
                "startedAt": FieldValue.serverTimestamp(),
                "isActive": true
            ])
        } catch { }
        #endif
    }
    
    private func muteAudio(videoId: String, timeRange: ContentMatch.MatchTimeRange) async {
        // Would integrate with transcoding service to mute specific time ranges
        print("🔇 Muting audio for video \(videoId) from \(timeRange.start) to \(timeRange.start + timeRange.duration)")
    }
    
    private func trackUsage(videoId: String, rightsholder: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("content_usage_tracking").document().setData([
                "videoId": videoId,
                "rightsholder": rightsholder,
                "trackedAt": FieldValue.serverTimestamp(),
                "views": 0,
                "revenue": 0.0
            ])
        } catch { }
        #endif
    }
    
    private func restoreContentPendingDispute(videoId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("videos").document(videoId).setData([
                "visibility": "public",
                "disputePending": true,
                "restoredAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch { }
        #endif
    }
    
    private func similarityScore(_ hash1: String, _ hash2: String) -> Double {
        // Simple hash comparison - in production would use proper fingerprint matching algorithms
        let commonChars = Set(hash1).intersection(Set(hash2)).count
        let totalChars = max(hash1.count, hash2.count)
        return totalChars > 0 ? Double(commonChars) / Double(totalChars) : 0.0
    }
}

enum DisputeResolution: String, CaseIterable {
    case upheld = "upheld"
    case rejected = "rejected"
    case settled = "settled"
}


