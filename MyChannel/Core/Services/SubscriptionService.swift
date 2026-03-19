import Foundation
import FirebaseAuth
import FirebaseFirestore
import StoreKit

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var isPlusSubscriber = false
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var subscriptionEndDate: Date?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    enum SubscriptionStatus: String {
        case free
        case trial
        case active
        case expired
    }
    
    private init() {
        setupSubscriptionListener()
    }
    
    func setupSubscriptionListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isPlusSubscriber = false
            return
        }
        
        listener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("Error listening to subscription: \(error)")
                        return
                    }
                    
                    guard let data = snapshot?.data() else { return }
                    
                    self.isPlusSubscriber = data["isPlusSubscriber"] as? Bool ?? false
                    
                    if let statusString = data["subscriptionStatus"] as? String,
                       let status = SubscriptionStatus(rawValue: statusString) {
                        self.subscriptionStatus = status
                    }
                    
                    if let timestamp = data["subscriptionEndDate"] as? Timestamp {
                        self.subscriptionEndDate = timestamp.dateValue()
                    }
                }
            }
    }
    
    func checkSubscription() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let isPlusSubscriber = doc.data()?["isPlusSubscriber"] as? Bool ?? false
            
            await MainActor.run {
                self.isPlusSubscriber = isPlusSubscriber
            }
            
            return isPlusSubscriber
        } catch {
            print("Error checking subscription: \(error)")
            return false
        }
    }
    
    func activatePlusSubscription() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SubscriptionError.notAuthenticated
        }
        
        let subscriptionData: [String: Any] = [
            "isPlusSubscriber": true,
            "subscriptionStatus": SubscriptionStatus.active.rawValue,
            "subscriptionStartDate": Timestamp(date: Date()),
            "subscriptionEndDate": Timestamp(date: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()),
            "lastUpdated": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).updateData(subscriptionData)
        
        await MainActor.run {
            self.isPlusSubscriber = true
            self.subscriptionStatus = .active
        }
    }
    
    func cancelSubscription() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SubscriptionError.notAuthenticated
        }
        
        try await db.collection("users").document(userId).updateData([
            "isPlusSubscriber": false,
            "subscriptionStatus": SubscriptionStatus.expired.rawValue,
            "lastUpdated": Timestamp(date: Date())
        ])
        
        await MainActor.run {
            self.isPlusSubscriber = false
            self.subscriptionStatus = .expired
        }
    }
    
    deinit {
        listener?.remove()
    }
}

enum SubscriptionError: LocalizedError {
    case notAuthenticated
    case subscriptionNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to manage subscription"
        case .subscriptionNotFound:
            return "No active subscription found"
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        }
    }
}
