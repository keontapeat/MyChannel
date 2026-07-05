//
//  UniversityWatchTrackingService.swift
//  MyChannel
//
//  Track watch time per career path and certificate progress
//  Integration with AI verification and real-time tracking
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UniversityWatchTrackingService: ObservableObject {
    static let shared = UniversityWatchTrackingService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    @Published var currentCareerPaths: [String: CareerPathProgress] = [:]
    @Published var totalUniversityHours: Double = 0

    /// Set when the server mints a new certificate for the current user while the
    /// listener is active. Drives the in-app celebration; cleared by the UI.
    @Published var newlyEarnedCertificate: UniversityCertificate?

    #if canImport(FirebaseFirestore)
    private var certificateListener: ListenerRegistration?
    #endif
    private var certificateListenerPrimed = false
    
    // MARK: - View Token Attestation

    /// Requests a single-use view-attestation token from `issueUniversityViewToken`
    /// for the given video. Call this once when playback genuinely starts. The
    /// returned token must be included with the corresponding watch event so the
    /// server can verify the watch against a real, server-minted view rather than
    /// a client-fabricated one. Best-effort: returns nil on any failure (network,
    /// rate limit, signed-out) and callers fall back to the weaker corroboration
    /// path server-side.
    func requestViewToken(videoId: String) async -> String? {
        guard let url = URL(string: "https://us-east1-mychannel-ca26d.cloudfunctions.net/issueUniversityViewToken") else {
            return nil
        }
        guard let idToken = try? await AuthTokenProvider.idToken() else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["data": ["videoId": videoId]])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let tokenId = result["tokenId"] as? String else { return nil }
            return tokenId
        } catch {
            print("⚠️ [University Tracking] View token request failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Watch Tracking (event-sourced, server-authoritative)

    /// Emit a raw watch event for MyChannel University.
    ///
    /// 🔒 The client no longer computes or writes career-path progress. It only
    /// records what was watched into `university_watch_events`; the
    /// `onUniversityWatchEvent` Cloud Function validates the watch, attributes it
    /// to career paths from the VIDEO's own metadata (not client-supplied), and
    /// writes `university_progress` via the Admin SDK — which in turn triggers
    /// server-side certificate issuance. This makes the credential impossible to
    /// forge from the client (see firestore.rules).
    ///
    /// Streak + points are also advanced server-side from this same event by the
    /// Cloud Function (writing `university_users`), so the leaderboard can't be
    /// spoofed by writing streak/points directly (see firestore.rules).
    func recordWatchEvent(
        userId: String,
        videoId: String,
        title: String,
        duration: TimeInterval,
        watchTime: TimeInterval,
        completionPercentage: Double,
        aiVerificationScore: Int? = nil,
        viewToken: String? = nil
    ) async throws {
        print("📊 [University Tracking] Watch event: \(title)")
        print("   Watched: \(Int(watchTime/60))m | Completion: \(Int(completionPercentage*100))%")

        // Quality gate mirrors the server; avoids emitting noise for trivial watches.
        guard completionPercentage >= 0.7 || (aiVerificationScore ?? 0) >= 70 else {
            print("⚠️ [University Tracking] Low-quality watch — not recorded")
            return
        }

        #if canImport(FirebaseFirestore)
        // tzOffsetMinutes lets the server compute the user's local streak day from
        // server time (the client can't fast-forward days; only the tz is honored).
        let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        var data: [String: Any] = [
            "userId": userId,
            "videoId": videoId,
            "title": title,
            "watchSeconds": watchTime,
            "completion": min(1.0, max(0.0, completionPercentage)),
            "tzOffsetMinutes": tzOffsetMinutes,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let aiVerificationScore { data["aiScore"] = aiVerificationScore }
        if let viewToken { data["viewToken"] = viewToken }

        do {
            try await db.collection("university_watch_events").addDocument(data: data)
            print("✅ [University Tracking] Watch event recorded (server will aggregate progress + streak)")
        } catch {
            print("⚠️ [University Tracking] Failed to record watch event: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Certificate Celebration Listener

    /// Listen for server-issued certificates for this user and surface an in-app
    /// celebration the instant one is minted. Because issuance is now async +
    /// server-side, this restores the immediate "Certificate Earned!" UX without
    /// the client ever writing the credential itself.
    func startCertificateListener(userId: String) {
        #if canImport(FirebaseFirestore)
        guard certificateListener == nil else { return }
        certificateListenerPrimed = false
        certificateListener = db.collection("university_certificates")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot else { return }
                let addedDocs = snapshot.documentChanges
                    .filter { $0.type == .added }
                    .map { $0.document.data() }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Skip the first snapshot (baseline of already-earned certs);
                    // only celebrate certificates minted after we start listening.
                    guard self.certificateListenerPrimed else {
                        self.certificateListenerPrimed = true
                        return
                    }
                    for data in addedDocs {
                        if let cert = try? self.parseCertificate(from: data) {
                            self.newlyEarnedCertificate = cert
                            HapticManager.shared.notification(type: .success)
                            NotificationCenter.default.post(
                                name: Notification.Name("UniversityCertificateEarned"),
                                object: cert
                            )
                        }
                    }
                }
            }
        #endif
    }

    func stopCertificateListener() {
        #if canImport(FirebaseFirestore)
        certificateListener?.remove()
        certificateListener = nil
        #endif
        certificateListenerPrimed = false
    }

    // MARK: - Fetch Progress
    
    func fetchUserProgress(userId: String) async throws -> [CareerPathProgress] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("university_progress")
            .document(userId)
            .collection("career_paths")
            .getDocuments()
        
        var progressList: [CareerPathProgress] = []
        
        for doc in snapshot.documents {
            if let progress = try? parseCareerPathProgress(
                from: doc.data(),
                careerPathId: doc.documentID,
                userId: userId
            ) {
                progressList.append(progress)
            }
        }
        
        // Update local cache
        currentCareerPaths = Dictionary(progressList.map { ($0.careerPathId, $0) }, uniquingKeysWith: { _, last in last })
        
        // Calculate total hours
        totalUniversityHours = progressList.map(\.totalHours).reduce(0, +)
        
        print("✅ [University Tracking] Loaded progress for \(progressList.count) career paths")
        print("   Total University Hours: \(Int(totalUniversityHours))")
        
        return progressList.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
        #else
        return []
        #endif
    }
    
    func fetchCareerPathProgress(userId: String, careerPathId: String) async throws -> CareerPathProgress? {
        #if canImport(FirebaseFirestore)
        let doc = try await db.collection("university_progress")
            .document(userId)
            .collection("career_paths")
            .document(careerPathId)
            .getDocument()
        
        if doc.exists, let data = doc.data() {
            return try parseCareerPathProgress(from: data, careerPathId: careerPathId, userId: userId)
        }
        #endif
        
        return nil
    }
    
    // MARK: - Fetch Certificates
    
    func fetchUserCertificates(userId: String) async throws -> [UniversityCertificate] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("university_certificates")
            .whereField("userId", isEqualTo: userId)
            .order(by: "earnedDate", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? parseCertificate(from: doc.data())
        }
        #else
        return []
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func parseCareerPathProgress(from data: [String: Any], careerPathId: String, userId: String) throws -> CareerPathProgress {
        CareerPathProgress(
            id: data["id"] as? String ?? "\(userId)_\(careerPathId)",
            userId: userId,
            careerPathId: careerPathId,
            totalHours: data["totalHours"] as? Double ?? 0,
            videosWatched: data["videosWatched"] as? Int ?? 0,
            videoIds: data["videoIds"] as? [String] ?? [],
            lastWatchedAt: (data["lastWatchedAt"] as? Timestamp)?.dateValue() ?? Date(),
            certificateProgress: data["certificateProgress"] as? Double ?? 0,
            certificateEarned: data["certificateEarned"] as? Bool ?? false,
            certificateEarnedDate: (data["certificateEarnedDate"] as? Timestamp)?.dateValue(),
            averageAIScore: data["averageAIScore"] as? Int ?? 0,
            skillsCovered: Set(data["skillsCovered"] as? [String] ?? [])
        )
    }
    
    private func parseCertificate(from data: [String: Any]) throws -> UniversityCertificate {
        UniversityCertificate(
            id: data["id"] as? String ?? UUID().uuidString,
            userId: data["userId"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            careerPathId: data["careerPathId"] as? String ?? "",
            careerPathName: data["careerPathName"] as? String ?? "",
            totalHours: data["totalHours"] as? Double ?? 0,
            videosCompleted: data["videosCompleted"] as? Int ?? 0,
            averageAIScore: data["averageAIScore"] as? Int ?? 0,
            earnedDate: (data["earnedDate"] as? Timestamp)?.dateValue() ?? Date(),
            verificationHash: data["verificationHash"] as? String,
            certificateNumber: data["certificateNumber"] as? String ?? "",
            skillsAcquired: data["skillsAcquired"] as? [String] ?? []
        )
    }
    
}

