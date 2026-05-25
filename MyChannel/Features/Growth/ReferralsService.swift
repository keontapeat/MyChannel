import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ReferralCode: Identifiable, Codable {
    let id: String
    let code: String
    let ownerId: String
    let createdAt: Date
    let expiresAt: Date?
    let maxUses: Int?
    let currentUses: Int
    let rewards: ReferralRewards
    let isActive: Bool
    
    struct ReferralRewards: Codable {
        let referrerBonus: Double // USD
        let refereeBonus: Double // USD
        let videoBonusThreshold: Int // views needed for bonus
        let videoBonusAmount: Double // USD
    }
}

struct ReferralConversion: Identifiable, Codable {
    let id: String
    let code: String
    let referrerId: String
    let refereeId: String
    let refereeEmail: String?
    let deviceInfo: DeviceInfo
    let conversionEvents: [ConversionEvent]
    let fraudScore: Double
    let isValid: Bool
    let createdAt: Date
    
    struct DeviceInfo: Codable {
        let ip: String
        let userAgent: String
        let platform: String
        let deviceId: String?
    }
    
    struct ConversionEvent: Codable {
        let type: EventType
        let timestamp: Date
        let metadata: [String: String]?
        
        enum EventType: String, Codable {
            case click, install, signup, firstVideo, retention7d
        }
    }
}

@MainActor
final class ReferralsService: ObservableObject {
    static let shared = ReferralsService()
    private init() {}
    
    @Published var myCodes: [ReferralCode] = []
    @Published var myConversions: [ReferralConversion] = []
    @Published var totalEarnings: Double = 0
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var codesListener: ListenerRegistration?
    private var conversionsListener: ListenerRegistration?
    #endif
    
    func generateReferralCode(userId: String, customCode: String? = nil) async -> ReferralCode? {
        let code = customCode ?? generateRandomCode()
        
        #if canImport(FirebaseFirestore)
        do {
            // Check if code already exists
            let existing = try await db.collection("referral_codes").whereField("code", isEqualTo: code).getDocuments()
            if !existing.documents.isEmpty {
                return nil // Code already exists
            }
            
            let ref = db.collection("referral_codes").document()
            let referralCode = ReferralCode(
                id: ref.documentID,
                code: code,
                ownerId: userId,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(365 * 24 * 3600), // 1 year
                maxUses: nil, // Unlimited
                currentUses: 0,
                rewards: ReferralCode.ReferralRewards(
                    referrerBonus: 5.0,
                    refereeBonus: 2.0,
                    videoBonusThreshold: 1000,
                    videoBonusAmount: 10.0
                ),
                isActive: true
            )
            
            try await ref.setData([
                "code": code,
                "ownerId": userId,
                "createdAt": FieldValue.serverTimestamp(),
                "expiresAt": Timestamp(date: referralCode.expiresAt!),
                "maxUses": referralCode.maxUses as Any,
                "currentUses": 0,
                "rewards": [
                    "referrerBonus": referralCode.rewards.referrerBonus,
                    "refereeBonus": referralCode.rewards.refereeBonus,
                    "videoBonusThreshold": referralCode.rewards.videoBonusThreshold,
                    "videoBonusAmount": referralCode.rewards.videoBonusAmount
                ],
                "isActive": true
            ])
            
            return referralCode
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func processReferralClick(code: String, deviceInfo: ReferralConversion.DeviceInfo) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            // Find referral code
            let codeQuery = try await db.collection("referral_codes").whereField("code", isEqualTo: code).getDocuments()
            guard let codeDoc = codeQuery.documents.first else { return false }
            
            let codeData = codeDoc.data()
            let referrerId = codeData["ownerId"] as? String ?? ""
            
            // Check for fraud
            let fraudScore = await calculateFraudScore(deviceInfo: deviceInfo, referrerId: referrerId)
            
            // Create conversion tracking
            let conversionRef = db.collection("referral_conversions").document()
            try await conversionRef.setData([
                "code": code,
                "referrerId": referrerId,
                "refereeId": "", // Will be filled on signup
                "deviceInfo": [
                    "ip": deviceInfo.ip,
                    "userAgent": deviceInfo.userAgent,
                    "platform": deviceInfo.platform,
                    "deviceId": deviceInfo.deviceId as Any
                ],
                "conversionEvents": [[
                    "type": ReferralConversion.ConversionEvent.EventType.click.rawValue,
                    "timestamp": FieldValue.serverTimestamp(),
                    "metadata": [:]
                ]],
                "fraudScore": fraudScore,
                "isValid": fraudScore < 0.7,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            return fraudScore < 0.7
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func completeReferralSignup(code: String, newUserId: String, userEmail: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            // Find pending conversion
            let conversionQuery = try await db.collection("referral_conversions")
                .whereField("code", isEqualTo: code)
                .whereField("refereeId", isEqualTo: "")
                .limit(to: 1)
                .getDocuments()
            
            guard let conversionDoc = conversionQuery.documents.first else { return false }
            
            // Update conversion with user info
            try await conversionDoc.reference.setData([
                "refereeId": newUserId,
                "refereeEmail": userEmail,
                "conversionEvents": FieldValue.arrayUnion([[
                    "type": ReferralConversion.ConversionEvent.EventType.signup.rawValue,
                    "timestamp": FieldValue.serverTimestamp(),
                    "metadata": ["userId": newUserId]
                ]])
            ], merge: true)
            
            // Update referral code usage count
            let codeQuery = try await db.collection("referral_codes").whereField("code", isEqualTo: code).getDocuments()
            if let codeDoc = codeQuery.documents.first {
                try await codeDoc.reference.setData([
                    "currentUses": FieldValue.increment(Int64(1))
                ], merge: true)
            }
            
            // Award bonuses
            await awardReferralBonuses(conversionId: conversionDoc.documentID, code: code)
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    func trackVideoMilestone(userId: String, videoId: String, views: Int) async {
        // Check if this user was referred and if they hit bonus thresholds
        #if canImport(FirebaseFirestore)
        do {
            let conversions = try await db.collection("referral_conversions")
                .whereField("refereeId", isEqualTo: userId)
                .getDocuments()
            
            for doc in conversions.documents {
                let data = doc.data()
                let code = data["code"] as? String ?? ""
                let referrerId = data["referrerId"] as? String ?? ""
                
                // Check if bonus threshold reached
                let codeQuery = try await db.collection("referral_codes").whereField("code", isEqualTo: code).getDocuments()
                if let codeDoc = codeQuery.documents.first {
                    let codeData = codeDoc.data()
                    let rewards = codeData["rewards"] as? [String: Any] ?? [:]
                    let threshold = rewards["videoBonusThreshold"] as? Int ?? 1000
                    let bonusAmount = rewards["videoBonusAmount"] as? Double ?? 10.0
                    
                    if views >= threshold {
                        // Award video bonus to referrer
                        await awardVideoBonus(referrerId: referrerId, amount: bonusAmount, videoId: videoId)
                        
                        // Track milestone event
                        try await doc.reference.setData([
                            "conversionEvents": FieldValue.arrayUnion([[
                                "type": "video_milestone",
                                "timestamp": FieldValue.serverTimestamp(),
                                "metadata": ["videoId": videoId, "views": views, "bonus": bonusAmount]
                            ]])
                        ], merge: true)
                    }
                }
            }
        } catch { }
        #endif
    }
    
    private func calculateFraudScore(deviceInfo: ReferralConversion.DeviceInfo, referrerId: String) async -> Double {
        var score = 0.0
        
        // Check IP patterns (simplified)
        if deviceInfo.ip.isEmpty { score += 0.3 }
        
        // Check for self-referral attempts
        #if canImport(FirebaseFirestore)
        do {
            let userQuery = try await db.collection("users").document(referrerId).getDocument()
            if let userData = userQuery.data(), let userIP = userData["lastKnownIP"] as? String {
                if userIP == deviceInfo.ip { score += 0.8 } // High fraud score for same IP
            }
        } catch { }
        #endif
        
        // Check user agent patterns
        if deviceInfo.userAgent.isEmpty || deviceInfo.userAgent.contains("bot") { score += 0.4 }
        
        // Check device ID reuse
        if let deviceId = deviceInfo.deviceId {
            #if canImport(FirebaseFirestore)
            do {
                let deviceQuery = try await db.collection("referral_conversions")
                    .whereField("deviceInfo.deviceId", isEqualTo: deviceId)
                    .getDocuments()
                if deviceQuery.documents.count > 3 { score += 0.5 } // Multiple uses of same device
            } catch { }
            #endif
        }
        
        return min(1.0, score)
    }
    
    private func awardReferralBonuses(conversionId: String, code: String) async {
        // Award signup bonuses - would integrate with payments system
        print("🎁 Awarding referral bonuses for conversion: \(conversionId)")
    }
    
    private func awardVideoBonus(referrerId: String, amount: Double, videoId: String) async {
        // Award video milestone bonus - would integrate with payments system
        print("🎁 Awarding video bonus: $\(amount) to \(referrerId) for video \(videoId)")
    }
    
    private func generateRandomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).compactMap { _ in characters.randomElement() })
    }
    
    func listenToMyCodes(userId: String) {
        #if canImport(FirebaseFirestore)
        codesListener?.remove()
        codesListener = db.collection("referral_codes")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.myCodes = docs.compactMap { doc in
                    let d = doc.data()
                    let rewards = d["rewards"] as? [String: Any] ?? [:]
                    return ReferralCode(
                        id: doc.documentID,
                        code: d["code"] as? String ?? "",
                        ownerId: d["ownerId"] as? String ?? "",
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        expiresAt: (d["expiresAt"] as? Timestamp)?.dateValue(),
                        maxUses: d["maxUses"] as? Int,
                        currentUses: d["currentUses"] as? Int ?? 0,
                        rewards: ReferralCode.ReferralRewards(
                            referrerBonus: rewards["referrerBonus"] as? Double ?? 0,
                            refereeBonus: rewards["refereeBonus"] as? Double ?? 0,
                            videoBonusThreshold: rewards["videoBonusThreshold"] as? Int ?? 1000,
                            videoBonusAmount: rewards["videoBonusAmount"] as? Double ?? 0
                        ),
                        isActive: d["isActive"] as? Bool ?? true
                    )
                }
            }
        #endif
        
        // Mock fallback
        if myCodes.isEmpty {
            myCodes = [
                ReferralCode(
                    id: "mock1",
                    code: "CREATOR2024",
                    ownerId: userId,
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(365 * 24 * 3600),
                    maxUses: nil,
                    currentUses: 12,
                    rewards: ReferralCode.ReferralRewards(
                        referrerBonus: 5.0,
                        refereeBonus: 2.0,
                        videoBonusThreshold: 1000,
                        videoBonusAmount: 10.0
                    ),
                    isActive: true
                )
            ]
        }
    }
    
    func listenToMyConversions(userId: String) {
        #if canImport(FirebaseFirestore)
        conversionsListener?.remove()
        conversionsListener = db.collection("referral_conversions")
            .whereField("referrerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.myConversions = docs.compactMap { doc in
                    let d = doc.data()
                    let deviceInfo = d["deviceInfo"] as? [String: Any] ?? [:]
                    let events = d["conversionEvents"] as? [[String: Any]] ?? []
                    
                    return ReferralConversion(
                        id: doc.documentID,
                        code: d["code"] as? String ?? "",
                        referrerId: d["referrerId"] as? String ?? "",
                        refereeId: d["refereeId"] as? String ?? "",
                        refereeEmail: d["refereeEmail"] as? String,
                        deviceInfo: ReferralConversion.DeviceInfo(
                            ip: deviceInfo["ip"] as? String ?? "",
                            userAgent: deviceInfo["userAgent"] as? String ?? "",
                            platform: deviceInfo["platform"] as? String ?? "",
                            deviceId: deviceInfo["deviceId"] as? String
                        ),
                        conversionEvents: events.compactMap { eventDict in
                            guard let type = eventDict["type"] as? String,
                                  let timestamp = (eventDict["timestamp"] as? Timestamp)?.dateValue() else { return nil }
                            return ReferralConversion.ConversionEvent(
                                type: ReferralConversion.ConversionEvent.EventType(rawValue: type) ?? .click,
                                timestamp: timestamp,
                                metadata: eventDict["metadata"] as? [String: String]
                            )
                        },
                        fraudScore: d["fraudScore"] as? Double ?? 0,
                        isValid: d["isValid"] as? Bool ?? true,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                
                // Calculate total earnings
                self.totalEarnings = self.myConversions.reduce(0) { total, conversion in
                    if conversion.isValid {
                        let signupBonus = self.myCodes.first(where: { $0.code == conversion.code })?.rewards.referrerBonus ?? 0
                        let videoBonus = Double(conversion.conversionEvents.filter { $0.type.rawValue == "video_milestone" }.count) * 10.0
                        return total + signupBonus + videoBonus
                    }
                    return total
                }
            }
        #endif
    }
    
    func generateShareableLink(code: String) -> String {
        return "https://mychannel.app/r/\(code)"
    }
    
    func deactivateCode(codeId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("referral_codes").document(codeId).setData([
                "isActive": false
            ], merge: true)
        } catch { }
        #endif
    }
    
    func stopListening() {
        #if canImport(FirebaseFirestore)
        codesListener?.remove()
        conversionsListener?.remove()
        #endif
    }
    
}
