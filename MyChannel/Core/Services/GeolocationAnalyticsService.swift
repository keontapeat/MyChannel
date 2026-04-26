//
//  GeolocationAnalyticsService.swift
//  MyChannel
//
//  Geolocation tracking for real regional analytics
//

import Foundation
import Combine
import CoreLocation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class GeolocationAnalyticsService: ObservableObject {
    static let shared = GeolocationAnalyticsService()
    
    @Published private(set) var regionalBreakdown: [RegionData] = []
    
    struct RegionData: Identifiable, Codable {
        let id: String
        let countryCode: String
        let countryName: String
        let userCount: Int
        let percentage: Double
    }
    
    private let locationManager = CLLocationManager()
    
    private init() {
        requestLocationPermission()
        Task { await loadRegionalData() }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func loadRegionalData() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("userLocations")
            .getDocuments()
        
        let countryCounts = Dictionary(grouping: snapshot?.documents ?? [], by: { $0.data()["countryCode"] as? String ?? "unknown" })
            .mapValues { $0.count }
        
        let totalUsers = countryCounts.values.reduce(0, +)
        
        let countryNames: [String: String] = [
            "US": "United States",
            "GB": "United Kingdom",
            "CA": "Canada",
            "AU": "Australia",
            "DE": "Germany",
            "FR": "France",
            "JP": "Japan",
            "BR": "Brazil",
            "IN": "India",
            "MX": "Mexico"
        ]
        
        regionalBreakdown = countryCounts.map { countryCode, count in
            RegionData(
                id: countryCode,
                countryCode: countryCode,
                countryName: countryNames[countryCode] ?? countryCode,
                userCount: count,
                percentage: totalUsers > 0 ? Double(count) / Double(totalUsers) * 100 : 0
            )
        }.sorted { $0.userCount > $1.userCount }
        #endif
    }
    
    func updateUserLocation(userId: String, countryCode: String, countryName: String?) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        try? await db.collection("userLocations").document(userId).setData([
            "userId": userId,
            "countryCode": countryCode,
            "countryName": countryName ?? countryCode,
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
        
        await loadRegionalData()
        #endif
    }
    
    func getCurrentCountryCode() -> String? {
        guard let location = locationManager.location else { return nil }
        let geocoder = CLGeocoder()
        let locale = Locale.current
        return locale.regionCode
    }
}
