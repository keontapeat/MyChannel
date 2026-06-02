//
//  LiveShoppingService.swift
//  MyChannel
//
//  Real Firestore-backed data layer for the Live Shopping (YouTube-style merch) experience.
//  Reads live shopping shows, products, creator shops, and flash sales from Firestore so the
//  Live Shopping screen shows real, wired content instead of hardcoded mocks.
//
//  Collections (project: mychannel-ca26d):
//    - live_shopping_shows      : live/scheduled shopping streams
//    - shopping_products        : product catalog (trending + flash sales)
//    - creator_shops            : creator storefront summaries
//    - shopping_metrics/global  : real-time aggregate dashboard metrics
//
//  Checkout is App Store Guideline 3.1.5(a)–compliant: physical goods are purchased through the
//  creator's external storefront URL (opened in SafariView), never through Apple IAP.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class LiveShoppingService: ObservableObject {
    static let shared = LiveShoppingService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    // MARK: - Live Shopping Shows

    func fetchLiveShows() async -> [LiveShoppingShow] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("live_shopping_shows")
                .whereField("isLive", isEqualTo: true)
                .order(by: "viewerCount", descending: true)
                .limit(to: 20)
                .getDocuments()
            let shows = snap.documents.compactMap { Self.show(from: $0.data(), id: $0.documentID) }
            return shows
        } catch {
            print("❌ [LiveShoppingService] fetchLiveShows: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: - Products (trending catalog)

    func fetchTrendingProducts(limit: Int = 20) async -> [ShoppingProduct] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("shopping_products")
                .whereField("isActive", isEqualTo: true)
                .order(by: "reviews", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { Self.product(from: $0.data(), id: $0.documentID) }
        } catch {
            print("❌ [LiveShoppingService] fetchTrendingProducts: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    func fetchFlashSaleProducts(limit: Int = 6) async -> [ShoppingProduct] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("shopping_products")
                .whereField("isFlashSale", isEqualTo: true)
                .whereField("isActive", isEqualTo: true)
                .order(by: "discount", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { Self.product(from: $0.data(), id: $0.documentID) }
        } catch {
            print("❌ [LiveShoppingService] fetchFlashSaleProducts: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    func searchProducts(query: String) async -> [ShoppingProduct] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        // Firestore has no native full-text search; fetch the active catalog and filter client-side.
        let all = await fetchTrendingProducts(limit: 100)
        return all.filter {
            $0.name.lowercased().contains(q) ||
            $0.brand.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }

    // MARK: - Creator Shops

    func fetchCreatorShops(limit: Int = 20) async -> [CreatorShop] {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("creator_shops")
                .order(by: "totalSales", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { Self.creatorShop(from: $0.data(), id: $0.documentID) }
        } catch {
            print("❌ [LiveShoppingService] fetchCreatorShops: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: - Metrics

    func fetchMetrics() async -> [ShoppingMetric] {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("shopping_metrics").document("global").getDocument()
            guard let d = doc.data() else { return [] }
            return Self.metrics(from: d)
        } catch {
            print("❌ [LiveShoppingService] fetchMetrics: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: - Order intent tracking (analytics only — purchase happens on external storefront)

    func trackProductView(productId: String) async {
        #if canImport(FirebaseFirestore)
        let uid = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id
        do {
            try await db.collection("shopping_products").document(productId)
                .setData(["views": FieldValue.increment(Int64(1))], merge: true)
            try await db.collection("shopping_events").document().setData([
                "type": "product_view",
                "productId": productId,
                "uid": uid as Any,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ [LiveShoppingService] trackProductView: \(error)")
        }
        #endif
    }

    func trackCheckoutTap(productId: String) async {
        #if canImport(FirebaseFirestore)
        let uid = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id
        do {
            try await db.collection("shopping_products").document(productId)
                .setData(["checkoutTaps": FieldValue.increment(Int64(1))], merge: true)
            try await db.collection("shopping_events").document().setData([
                "type": "checkout_tap",
                "productId": productId,
                "uid": uid as Any,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ [LiveShoppingService] trackCheckoutTap: \(error)")
        }
        #endif
    }

    // MARK: - Parsers

    #if canImport(FirebaseFirestore)
    private static func show(from d: [String: Any], id: String) -> LiveShoppingShow? {
        let creatorData = d["creator"] as? [String: Any] ?? [:]
        let creator = LiveShoppingShow.ShowCreator(
            id: creatorData["id"] as? String ?? "",
            name: creatorData["name"] as? String ?? "Creator",
            avatarURL: creatorData["avatarURL"] as? String ?? ""
        )
        let start: Date = (d["startTime"] as? Timestamp)?.dateValue() ?? Date()
        return LiveShoppingShow(
            id: id,
            title: d["title"] as? String ?? "",
            description: d["description"] as? String ?? "",
            thumbnailURL: d["thumbnailURL"] as? String ?? "",
            creator: creator,
            startTime: start,
            viewerCount: d["viewerCount"] as? Int ?? 0,
            featuredProducts: d["featuredProducts"] as? [String] ?? [],
            isLive: d["isLive"] as? Bool ?? false
        )
    }

    private static func product(from d: [String: Any], id: String) -> ShoppingProduct? {
        let categoryRaw = d["category"] as? String ?? "fashion"
        return ShoppingProduct(
            id: id,
            name: d["name"] as? String ?? "",
            description: d["description"] as? String ?? "",
            price: d["price"] as? Double ?? 0,
            originalPrice: d["originalPrice"] as? Int ?? Int(d["price"] as? Double ?? 0),
            discount: d["discount"] as? Int ?? 0,
            imageURL: d["imageURL"] as? String ?? "",
            category: ShoppingCategory(rawValue: categoryRaw) ?? .fashion,
            creatorId: d["creatorId"] as? String ?? "",
            creatorCommission: d["creatorCommission"] as? Double ?? 0,
            rating: d["rating"] as? Double ?? 0,
            reviews: d["reviews"] as? Int ?? 0,
            hasARTryOn: d["hasARTryOn"] as? Bool ?? false,
            stockRemaining: d["stockRemaining"] as? Int ?? 0,
            brand: d["brand"] as? String ?? "",
            storefrontURL: d["storefrontURL"] as? String
        )
    }

    private static func creatorShop(from d: [String: Any], id: String) -> CreatorShop? {
        let creatorData = d["creator"] as? [String: Any] ?? [:]
        let creator = LiveShoppingShow.ShowCreator(
            id: creatorData["id"] as? String ?? "",
            name: creatorData["name"] as? String ?? "Creator",
            avatarURL: creatorData["avatarURL"] as? String ?? ""
        )
        return CreatorShop(
            id: id,
            creator: creator,
            productCount: d["productCount"] as? Int ?? 0,
            totalSales: d["totalSales"] as? Int ?? 0,
            rating: d["rating"] as? Double ?? 0,
            storefrontURL: d["storefrontURL"] as? String
        )
    }

    private static func metrics(from d: [String: Any]) -> [ShoppingMetric] {
        var result: [ShoppingMetric] = []
        if let v = d["ordersToday"] as? String ?? (d["ordersToday"] as? Int).map(String.init) {
            result.append(ShoppingMetric(title: "Orders today", value: v,
                                         trend: d["ordersTrend"] as? String ?? "",
                                         icon: "bag.fill", iconColor: AppTheme.Colors.primary))
        }
        if let v = d["avgOrderValue"] as? String {
            result.append(ShoppingMetric(title: "Avg. order value", value: v,
                                         trend: d["avgOrderTrend"] as? String ?? "",
                                         icon: "dollarsign.arrow.circlepath", iconColor: AppTheme.Colors.secondary))
        }
        if let v = d["liveViewers"] as? String {
            result.append(ShoppingMetric(title: "Live viewers", value: v,
                                         trend: d["liveViewersTrend"] as? String ?? "",
                                         icon: "person.3.sequence.fill", iconColor: AppTheme.Colors.accent))
        }
        if let v = d["conversionRate"] as? String {
            result.append(ShoppingMetric(title: "Conversion rate", value: v,
                                         trend: d["conversionTrend"] as? String ?? "",
                                         icon: "chart.bar.xaxis", iconColor: AppTheme.Colors.verificationBlue))
        }
        return result
    }
    #endif
}
