#if canImport(RevenueCat)
import RevenueCat
#endif
import Foundation

/// RevenueCat IAP & Subscription Management
/// Handles MyChannel Plus+ entitlements, receipt validation, and cross-platform restore.
@MainActor
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published var isPlusSubscriber: Bool = false
    @Published var isLoading: Bool = false
    @Published var availablePackages: [Any] = []

    private let monthlyProductID = "com.mychannel.plus.monthly"
    private let annualProductID  = "com.mychannel.plus.annual"

    private init() {}

    func configure(apiKey: String) {
        #if canImport(RevenueCat)
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: apiKey)
        print("✅ [RevenueCat] Configured.")
        Task { await refreshEntitlements() }
        #endif
    }

    func refreshEntitlements() async {
        #if canImport(RevenueCat)
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPlusSubscriber = customerInfo.entitlements["plus"]?.isActive == true
            print("✅ [RevenueCat] Plus active: \(isPlusSubscriber)")
        } catch {
            print("⚠️ [RevenueCat] Failed to refresh entitlements: \(error)")
        }
        #endif
    }

    func fetchOfferings() async {
        #if canImport(RevenueCat)
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                availablePackages = current.availablePackages
                print("✅ [RevenueCat] \(current.availablePackages.count) packages loaded.")
            }
        } catch {
            print("⚠️ [RevenueCat] Failed to fetch offerings: \(error)")
        }
        #endif
    }

    func purchase(package: Any) async throws -> Bool {
        #if canImport(RevenueCat)
        guard let rcPackage = package as? Package else { return false }
        let result = try await Purchases.shared.purchase(package: rcPackage)
        isPlusSubscriber = result.customerInfo.entitlements["plus"]?.isActive == true
        return isPlusSubscriber
        #else
        return false
        #endif
    }

    func restorePurchases() async throws {
        #if canImport(RevenueCat)
        let customerInfo = try await Purchases.shared.restorePurchases()
        isPlusSubscriber = customerInfo.entitlements["plus"]?.isActive == true
        print("✅ [RevenueCat] Restored. Plus active: \(isPlusSubscriber)")
        #endif
    }

    func logOut() {
        #if canImport(RevenueCat)
        Task {
            try? await Purchases.shared.logOut()
            isPlusSubscriber = false
        }
        #endif
    }
}
