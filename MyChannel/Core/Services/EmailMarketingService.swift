import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct EmailCampaign: Identifiable, Codable {
    let id: String
    let name: String
    let type: CampaignType
    let subject: String
    let content: String
    let targetSegment: UserSegment
    let scheduledAt: Date?
    let status: CampaignStatus
    let metrics: CampaignMetrics
    let createdAt: Date
    
    enum CampaignType: String, Codable, CaseIterable {
        case onboarding, retention, winback, promotional, newsletter
        
        var displayName: String {
            switch self {
            case .onboarding: return "Onboarding"
            case .retention: return "Retention"
            case .winback: return "Win-back"
            case .promotional: return "Promotional"
            case .newsletter: return "Newsletter"
            }
        }
    }
    
    enum CampaignStatus: String, Codable {
        case draft, scheduled, sending, sent, paused
    }
    
    struct CampaignMetrics: Codable {
        let sent: Int
        let delivered: Int
        let opened: Int
        let clicked: Int
        let unsubscribed: Int
        let bounced: Int
        
        var openRate: Double {
            delivered > 0 ? Double(opened) / Double(delivered) : 0
        }
        
        var clickRate: Double {
            delivered > 0 ? Double(clicked) / Double(delivered) : 0
        }
        
        var unsubscribeRate: Double {
            delivered > 0 ? Double(unsubscribed) / Double(delivered) : 0
        }
    }
}

struct UserSegment: Codable {
    let name: String
    let criteria: SegmentCriteria
    let estimatedSize: Int
    
    struct SegmentCriteria: Codable {
        let signupDateRange: DateRange?
        let lastActiveRange: DateRange?
        let hasUploadedVideo: Bool?
        let subscriberCountRange: IntRange?
        let watchTimeRange: TimeRange?
        let preferredCategories: [String]?
        let deviceTypes: [String]?
        let regions: [String]?
        
        struct DateRange: Codable {
            let start: Date
            let end: Date
        }
        
        struct IntRange: Codable {
            let min: Int
            let max: Int
        }
        
        struct TimeRange: Codable {
            let min: TimeInterval
            let max: TimeInterval
        }
    }
}

struct EmailTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let type: EmailCampaign.CampaignType
    let subject: String
    let htmlContent: String
    let textContent: String
    let variables: [String] // Template variables like {{username}}
    let previewText: String
    let isActive: Bool
}

@MainActor
final class EmailMarketingService: ObservableObject {
    static let shared = EmailMarketingService()
    private init() {}
    
    @Published var campaigns: [EmailCampaign] = []
    @Published var templates: [EmailTemplate] = []
    @Published var segments: [UserSegment] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    func setupOnboardingDrips(userId: String, userEmail: String) async {
        let campaigns = [
            (delay: 0, template: "welcome", subject: "Welcome to MyChannel! 🎬"),
            (delay: 86400, template: "profile_setup", subject: "Complete your profile"),
            (delay: 259200, template: "first_upload", subject: "Ready to share your first video?"),
            (delay: 604800, template: "growth_tips", subject: "5 tips to grow your channel"),
            (delay: 1209600, template: "monetization", subject: "Start earning with your content")
        ]
        
        for (index, campaign) in campaigns.enumerated() {
            await scheduleEmail(
                userId: userId,
                email: userEmail,
                template: campaign.template,
                subject: campaign.subject,
                scheduledAt: Date().addingTimeInterval(TimeInterval(campaign.delay)),
                campaignType: .onboarding,
                sequence: index + 1
            )
        }
    }
    
    func setupRetentionCampaign(userId: String, userEmail: String, lastActiveDate: Date) async {
        let daysSinceActive = Date().timeIntervalSince(lastActiveDate) / 86400
        
        if daysSinceActive >= 7 && daysSinceActive < 14 {
            // Win-back campaign
            await scheduleEmail(
                userId: userId,
                email: userEmail,
                template: "winback_7d",
                subject: "We miss you! Here's what's new",
                scheduledAt: Date().addingTimeInterval(3600),
                campaignType: .winback
            )
        } else if daysSinceActive >= 30 {
            // Strong win-back with incentive
            await scheduleEmail(
                userId: userId,
                email: userEmail,
                template: "winback_30d",
                subject: "Come back for exclusive creator perks",
                scheduledAt: Date().addingTimeInterval(3600),
                campaignType: .winback
            )
        }
    }
    
    func createSegment(name: String, criteria: UserSegment.SegmentCriteria) async -> String? {
        let estimatedSize = await calculateSegmentSize(criteria: criteria)
        
        let segment = UserSegment(
            name: name,
            criteria: criteria,
            estimatedSize: estimatedSize
        )
        
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("email_segments").document()
            try await ref.setData([
                "name": segment.name,
                "criteria": try JSONEncoder().encode(segment.criteria).base64EncodedString(),
                "estimatedSize": segment.estimatedSize,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func sendCampaign(campaignId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            // Get campaign
            let campaignDoc = try await db.collection("email_campaigns").document(campaignId).getDocument()
            guard let campaignData = campaignDoc.data() else { return false }
            
            let segmentId = campaignData["targetSegment"] as? String ?? ""
            let users = await getUsersInSegment(segmentId: segmentId)
            
            var sent = 0
            var delivered = 0
            
            for user in users {
                let success = await sendEmail(
                    to: user.email,
                    subject: campaignData["subject"] as? String ?? "",
                    content: campaignData["content"] as? String ?? "",
                    userId: user.id
                )
                
                if success {
                    sent += 1
                    delivered += 1 // Simplified - would track actual delivery
                }
            }
            
            // Update campaign metrics
            try await campaignDoc.reference.setData([
                "status": EmailCampaign.CampaignStatus.sent.rawValue,
                "metrics": [
                    "sent": sent,
                    "delivered": delivered,
                    "opened": 0,
                    "clicked": 0,
                    "unsubscribed": 0,
                    "bounced": 0
                ],
                "sentAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    private func scheduleEmail(userId: String, email: String, template: String, subject: String, scheduledAt: Date, campaignType: EmailCampaign.CampaignType, sequence: Int = 1) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("scheduled_emails").document().setData([
                "userId": userId,
                "email": email,
                "template": template,
                "subject": subject,
                "scheduledAt": Timestamp(date: scheduledAt),
                "campaignType": campaignType.rawValue,
                "sequence": sequence,
                "status": "scheduled",
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
    
    private func sendEmail(to email: String, subject: String, content: String, userId: String) async -> Bool {
        // Integrate with email service (SendGrid, Mailgun, etc.)
        do {
            guard let url = URL(string: "https://api.sendgrid.v3/mail/send") else { return false }
            
            let emailData: [String: Any] = [
                "personalizations": [[
                    "to": [["email": email]],
                    "subject": subject
                ]],
                "from": ["email": "noreply@mychannel.app", "name": "MyChannel"],
                "content": [[
                    "type": "text/html",
                    "value": content
                ]],
                "tracking_settings": [
                    "click_tracking": ["enable": true],
                    "open_tracking": ["enable": true]
                ]
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer YOUR_SENDGRID_API_KEY", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch { }
        
        return false
    }
    
    private func calculateSegmentSize(criteria: UserSegment.SegmentCriteria) async -> Int {
        // Calculate estimated segment size based on criteria
        return Int.random(in: 1000...50000) // Mock for now
    }
    
    private func getUsersInSegment(segmentId: String) async -> [User] {
        // Get users matching segment criteria
        return Array(User.sampleUsers.prefix(100)) // Mock for now
    }
}
