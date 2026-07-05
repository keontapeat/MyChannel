import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct ContentMatch: Identifiable, Codable {
    let id: String
    let sourceVideoId: String
    let matchedVideoId: String
    let matchType: MatchType
    let confidence: Double
    let timeRange: MatchTimeRange
    let rightsholder: String
    let ownerId: String?
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

    /// Real general-video Content ID backend (perceptual frame-hash matching —
    /// see services/video-content-id/fingerprint.ts). Distinct from
    /// AppConfig.API.musicContentIDBaseURL, which handles audio-only tracks
    /// via Chromaprint. Replaces the previous simulated fingerprint generation
    /// (Task.sleep + character-set-overlap "similarity") with real ffmpeg-based
    /// perceptual hashing running server-side, robust to re-encoding.
    private let videoContentIDBaseURL = AppConfig.API.videoContentIDBaseURL

    @Published var activeMatches: [ContentMatch] = []
    @Published var referenceFiles: [ContentIDReference] = []

    private func authorizedRequest(path: String, method: String, body: [String: Any]) async throws -> URLRequest {
        guard let url = URL(string: videoContentIDBaseURL + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        #if canImport(FirebaseAuth)
        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        #endif
        return request
    }

    /// Scans an uploaded video against the Content ID reference database.
    /// `sourceUri` must be a `gs://` or `storage.googleapis.com` URL the
    /// backend can download and run ffmpeg frame extraction against (see
    /// services/video-content-id/main.ts `/v1/video/content-id/scan`).
    func scanForMatches(videoId: String, sourceUri: String) async -> [ContentMatch] {
        do {
            let request = try await authorizedRequest(
                path: "/v1/video/content-id/scan",
                method: "POST",
                body: ["videoId": videoId, "sourceUri": sourceUri]
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("🚨 [ContentID] scan failed with non-200 response")
                return []
            }
            let decoded = try JSONDecoder().decode(ScanResponse.self, from: data)
            let matches = decoded.matches.map { $0.toContentMatch(matchedVideoId: videoId) }
            activeMatches.append(contentsOf: matches)
            return matches
        } catch {
            print("🚨 [ContentID] scan error: \(error)")
            return []
        }
    }

    /// Registers a video as a protected Content ID reference. `sourceUri`
    /// must point at the already-uploaded source file in Cloud Storage
    /// (`gs://` or `storage.googleapis.com`), matching the storage path
    /// convention `videos/{userId}/{videoId}/{filename}`.
    func uploadReferenceFile(title: String, rightsholder: String, ownerId: String? = nil, videoId: String, sourceUri: String, policy: ContentMatch.MatchPolicy) async -> String? {
        do {
            var body: [String: Any] = [
                "videoId": videoId,
                "sourceUri": sourceUri,
                "policy": policy.rawValue,
                "title": title,
                "rightsholder": rightsholder,
            ]
            if let ownerId { body["ownerId"] = ownerId }

            let request = try await authorizedRequest(
                path: "/v1/video/content-id/register",
                method: "POST",
                body: body
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("🚨 [ContentID] register failed with non-200 response")
                return nil
            }
            let decoded = try JSONDecoder().decode(RegisterResponse.self, from: data)
            return decoded.referenceId
        } catch {
            print("🚨 [ContentID] register error: \(error)")
            return nil
        }
    }

    /// Registers a music track's audio for Content ID by having the backend
    /// download the already-uploaded audio file and run real Chromaprint
    /// fingerprinting (services/music/content-id.ts `/register-from-url`).
    /// This hits the music Content ID service (audio fingerprinting), distinct
    /// from `uploadReferenceFile` above which hits the video service (frame
    /// hashing). `audioURL` is the Firebase Storage download URL returned
    /// after uploading the track (e.g. `music/{uid}/tracks/{trackId}.m4a`).
    func registerMusicTrack(trackId: String, audioURL: String, policy: ContentMatch.MatchPolicy) async -> String? {
        guard let url = URL(string: AppConfig.API.musicContentIDBaseURL + "/v1/music/content-id/register-from-url") else {
            return nil
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["trackId": trackId, "audioURL": audioURL])
            #if canImport(FirebaseAuth)
            if let token = try? await Auth.auth().currentUser?.getIDToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            #endif

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("🚨 [ContentID] music register failed with non-200 response")
                return nil
            }
            let decoded = try JSONDecoder().decode(RegisterResponse.self, from: data)
            // Policy is applied via the separate copyright-policy endpoint since
            // register-from-url always starts a track at the 'strict' default.
            if policy != .track {
                await setMusicCopyrightPolicy(trackId: trackId, policy: policy)
            }
            return decoded.referenceId
        } catch {
            print("🚨 [ContentID] music register error: \(error)")
            return nil
        }
    }

    private func setMusicCopyrightPolicy(trackId: String, policy: ContentMatch.MatchPolicy) async {
        // Music Content ID uses its own policy vocabulary (strict/monetize/allow)
        // rather than the video service's (block/monetize/track/mute). Map the
        // closest equivalent.
        let musicPolicy: String
        switch policy {
        case .block: musicPolicy = "strict"
        case .monetize: musicPolicy = "monetize"
        case .track, .mute: musicPolicy = "allow"
        }
        guard let url = URL(string: AppConfig.API.musicContentIDBaseURL + "/v1/music/tracks/\(trackId)/copyright-policy") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["policy": musicPolicy])
            #if canImport(FirebaseAuth)
            if let token = try? await Auth.auth().currentUser?.getIDToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            #endif
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("🚨 [ContentID] set music copyright policy error: \(error)")
        }
    }

    // MARK: - Backend response models

    private struct RegisterResponse: Decodable {
        let referenceId: String
    }

    private struct ScanResponse: Decodable {
        let matches: [ScanMatch]
    }

    private struct ScanMatch: Decodable {
        let matchId: String
        let sourceVideoId: String
        let rightsholder: String
        let ownerId: String?
        let policy: String
        let similarity: Double

        func toContentMatch(matchedVideoId: String) -> ContentMatch {
            ContentMatch(
                id: matchId,
                sourceVideoId: sourceVideoId,
                matchedVideoId: matchedVideoId,
                matchType: .video,
                confidence: similarity,
                timeRange: ContentMatch.MatchTimeRange(start: 0, duration: 0, sourceStart: 0),
                rightsholder: rightsholder,
                ownerId: ownerId,
                policy: ContentMatch.MatchPolicy(rawValue: policy) ?? .track,
                claimId: nil,
                status: .active,
                createdAt: Date()
            )
        }
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
    
    // NOTE: match-policy enforcement (block/monetize/track/mute) now happens
    // server-side in services/video-content-id/main.ts applyMatchPolicy(),
    // atomically with match creation during the scan — not duplicated here.

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
}

enum DisputeResolution: String, CaseIterable {
    case upheld = "upheld"
    case rejected = "rejected"
    case settled = "settled"
}


