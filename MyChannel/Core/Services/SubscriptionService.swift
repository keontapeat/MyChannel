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
    @Published var activeProductID: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?
    
    enum SubscriptionStatus: String {
        case free
        case trial
        case active
        case expired
    }
    
    private init() {
        setupSubscriptionListener()
        
        // Re-setup listener when auth state changes (login/logout)
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.listener?.remove()
                if user != nil {
                    self?.setupSubscriptionListener()
                } else {
                    self?.isPlusSubscriber = false
                    self?.subscriptionStatus = .free
                    self?.subscriptionEndDate = nil
                    self?.activeProductID = nil
                }
            }
        }
    }
    
    func setupSubscriptionListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isPlusSubscriber = false
            return
        }
        
        listener?.remove()
        listener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("⚠️ [Subscription] Listener error: \(error)")
                        return
                    }
                    
                    guard let data = snapshot?.data() else { return }
                    
                    self.isPlusSubscriber = data["isPlusSubscriber"] as? Bool ?? false
                    self.activeProductID = data["activeProductID"] as? String
                    
                    if let statusString = data["subscriptionStatus"] as? String,
                       let status = SubscriptionStatus(rawValue: statusString) {
                        self.subscriptionStatus = status
                    }
                    
                    if let timestamp = data["subscriptionEndDate"] as? Timestamp {
                        self.subscriptionEndDate = timestamp.dateValue()
                    }
                    
                    print("👑 [Subscription] Firestore sync — isPlusSubscriber: \(self.isPlusSubscriber), status: \(self.subscriptionStatus)")
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
            
            self.isPlusSubscriber = isPlusSubscriber
            return isPlusSubscriber
        } catch {
            print("⚠️ [Subscription] Check error: \(error)")
            return false
        }
    }
    
    // MARK: - Activate (called by StoreKitService after verified purchase)
    
    func activatePlusSubscription() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SubscriptionError.notAuthenticated
        }
        
        // Get the real expiry from StoreKit if available
        let expiryDate = await StoreKitService.shared.currentSubscriptionExpiry()
        let productID = StoreKitService.shared.activeSubscriptionProductID
        
        var subscriptionData: [String: Any] = [
            "isPlusSubscriber": true,
            "subscriptionStatus": SubscriptionStatus.active.rawValue,
            "subscriptionStartDate": Timestamp(date: Date()),
            "lastUpdated": Timestamp(date: Date())
        ]
        
        // Use real StoreKit expiry or fallback to +1 month
        if let expiry = expiryDate {
            subscriptionData["subscriptionEndDate"] = Timestamp(date: expiry)
        } else {
            subscriptionData["subscriptionEndDate"] = Timestamp(date: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
        }
        
        if let productID = productID {
            subscriptionData["activeProductID"] = productID
        }
        
        // Use merge so it works even if these fields don't exist yet
        try await db.collection("users").document(userId).setData(subscriptionData, merge: true)
        
        self.isPlusSubscriber = true
        self.subscriptionStatus = .active
        self.activeProductID = productID
        if let expiry = expiryDate {
            self.subscriptionEndDate = expiry
        }
        
        print("✅ [Subscription] Activated in Firestore for user \(userId)")
    }
    
    // MARK: - Cancel / Expire (called by StoreKitService when entitlements are lost)
    
    func cancelSubscription() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SubscriptionError.notAuthenticated
        }
        
        let cancelData: [String: Any] = [
            "isPlusSubscriber": false,
            "subscriptionStatus": SubscriptionStatus.expired.rawValue,
            "activeProductID": FieldValue.delete(),
            "lastUpdated": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).updateData(cancelData)
        
        self.isPlusSubscriber = false
        self.subscriptionStatus = .expired
        self.activeProductID = nil
        
        print("🚫 [Subscription] Cancelled in Firestore for user \(userId)")
    }
    
    deinit {
        listener?.remove()
        if let authListener = authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
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
