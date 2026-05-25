import Foundation
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// ✅ Renamed to avoid conflict with AdModels.AdRequest
struct WaterfallAdRequest: Codable {
    let requestId: String
    let videoId: String
    let userId: String?
    let placement: AdPlacement  // ✅ Use shared AdPlacement from AdModels
    let targeting: AdTargeting
    let timestamp: Date
    
    // ✅ Removed nested AdPlacement enum - using shared one from AdModels
    
    struct AdTargeting: Codable {
        let age: Int?
        let gender: String?
        let interests: [String]
        let location: String
        let deviceType: String
        let connectionType: String
    }
}

struct AdResponse: Codable {
    let requestId: String
    let adId: String?
    let source: AdSource
    let creativeURL: String?
    let clickURL: String?
    let impressionURL: String?
    let duration: TimeInterval?
    let cpm: Double
    let currency: String
    let fillRate: Double
    
    enum AdSource: String, Codable {
        case direct, admob, admanager, openrtb, house
        
        var priority: Int {
            switch self {
            case .direct: return 1      // Highest eCPM
            case .admanager: return 2   // Google Ad Manager
            case .admob: return 3       // AdMob
            case .openrtb: return 4     // OpenRTB partners
            case .house: return 5       // House ads (lowest)
            }
        }
    }
}

@MainActor
final class AdWaterfallService: ObservableObject {
    static let shared = AdWaterfallService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private var waterfallConfig: WaterfallConfig = WaterfallConfig.defaultConfig
    
    func requestAd(for request: WaterfallAdRequest) async -> AdResponse? {
        // Try sources in order of priority/eCPM
        let sources = waterfallConfig.sources.sorted { $0.priority < $1.priority }
        
        for source in sources {
            if let response = await tryAdSource(source, request: request) {
                // Log successful fill
                await logAdFill(request: request, response: response)
                return response
            }
        }
        
        // Fallback to house ad if all sources fail
        return createHouseAd(for: request)
    }
    
    private func tryAdSource(_ source: WaterfallSource, request: WaterfallAdRequest) async -> AdResponse? {
        switch source.type {
        case .direct:
            return await requestDirectAd(request: request)
        case .admob:
            return await requestAdMobAd(request: request)
        case .admanager:
            return await requestAdManagerAd(request: request)
        case .openrtb:
            return await requestOpenRTBAd(request: request)
        case .house:
            return createHouseAd(for: request)
        }
    }
    
    private func requestDirectAd(request: WaterfallAdRequest) async -> AdResponse? {
        // Request from direct ad partnerships
        do {
            guard let url = URL(string: "\(AppConfig.API.adsBaseURL)/ads/direct") else { return nil }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(AdResponse.self, from: data)
            }
        } catch { }
        
        return nil
    }
    
    private func requestAdMobAd(request: WaterfallAdRequest) async -> AdResponse? {
        #if canImport(GoogleMobileAds)
        return await withCheckedContinuation { continuation in
            // Configure AdMob request
            let gadRequest = GADRequest()
            
            // Set targeting
            if let age = request.targeting.age {
                gadRequest.birthday = Calendar.current.date(byAdding: .year, value: -age, to: Date())
            }
            
            if let gender = request.targeting.gender {
                gadRequest.gender = gender == "male" ? .male : (gender == "female" ? .female : .unknown)
            }
            
            // Request interstitial ad
            GADInterstitialAd.load(withAdUnitID: "ca-app-pub-YOUR_PUBLISHER_ID/YOUR_AD_UNIT_ID", request: gadRequest) { ad, error in
                if let error = error {
                    print("AdMob error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                if let ad = ad {
                    let response = AdResponse(
                        requestId: request.requestId,
                        adId: "admob_\(UUID().uuidString)",
                        source: .admob,
                        creativeURL: nil, // AdMob handles creative internally
                        clickURL: nil,
                        impressionURL: nil,
                        duration: 30, // Typical interstitial duration
                        cpm: Double.random(in: 1.0...5.0),
                        currency: "USD",
                        fillRate: 0.85
                    )
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        #else
        return nil
        #endif
    }
    
    private func requestAdManagerAd(request: WaterfallAdRequest) async -> AdResponse? {
        // Google Ad Manager integration
        do {
            guard let url = URL(string: "https://pubads.g.doubleclick.net/gampad/ads") else { return nil }
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "iu", value: "/YOUR_NETWORK_ID/YOUR_AD_UNIT"),
                URLQueryItem(name: "sz", value: "1x1"), // Size for video ads
                URLQueryItem(name: "vid", value: request.videoId),
                URLQueryItem(name: "cust_params", value: buildCustomParams(request: request))
            ]
            
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Parse Ad Manager response (simplified)
                return AdResponse(
                    requestId: request.requestId,
                    adId: "gam_\(UUID().uuidString)",
                    source: .admanager,
                    creativeURL: extractCreativeURL(from: data),
                    clickURL: extractClickURL(from: data),
                    impressionURL: extractImpressionURL(from: data),
                    duration: 15,
                    cpm: Double.random(in: 2.0...8.0),
                    currency: "USD",
                    fillRate: 0.75
                )
            }
        } catch { }
        
        return nil
    }
    
    private func requestOpenRTBAd(request: WaterfallAdRequest) async -> AdResponse? {
        // OpenRTB 2.5 request
        do {
            guard let url = URL(string: "\(AppConfig.API.adsBaseURL)/ads/openrtb") else { return nil }
            
            let bidRequest = OpenRTBBidRequest(
                id: request.requestId,
                imp: [OpenRTBImp(
                    id: "1",
                    video: OpenRTBVideo(
                        w: 1920,
                        h: 1080,
                        minduration: 5,
                        maxduration: 30,
                        protocols: [2, 3, 5, 6], // VAST protocols
                        mimes: ["video/mp4", "video/webm"]
                    )
                )],
                app: OpenRTBApp(
                    id: Bundle.main.bundleIdentifier ?? "",
                    name: "MyChannel",
                    bundle: Bundle.main.bundleIdentifier ?? ""
                ),
                device: OpenRTBDevice(
                    ua: "MyChannel iOS App",
                    ip: request.targeting.location,
                    devicetype: 1, // Mobile
                    os: "iOS"
                ),
                user: OpenRTBUser(
                    yob: request.targeting.age.map { 2024 - $0 },
                    gender: request.targeting.gender?.first?.uppercased()
                )
            )
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(bidRequest)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let bidResponse = try JSONDecoder().decode(OpenRTBBidResponse.self, from: data)
                
                if let seatbid = bidResponse.seatbid.first,
                   let bid = seatbid.bid.first {
                    return AdResponse(
                        requestId: request.requestId,
                        adId: bid.id,
                        source: .openrtb,
                        creativeURL: bid.adm, // VAST XML URL
                        clickURL: bid.nurl,
                        impressionURL: bid.iurl,
                        duration: 15,
                        cpm: bid.price,
                        currency: bidResponse.cur ?? "USD",
                        fillRate: 0.60
                    )
                }
            }
        } catch { }
        
        return nil
    }
    
    private func createHouseAd(for request: WaterfallAdRequest) -> AdResponse {
        let houseAds = [
            "https://storage.googleapis.com/mychannel-ads/house/download_app.mp4",
            "https://storage.googleapis.com/mychannel-ads/house/premium_signup.mp4",
            "https://storage.googleapis.com/mychannel-ads/house/creator_tools.mp4"
        ]
        
        return AdResponse(
            requestId: request.requestId,
            adId: "house_\(UUID().uuidString)",
            source: .house,
            creativeURL: houseAds.randomElement(),
            clickURL: "https://mychannel.app/premium",
            impressionURL: nil,
            duration: 20,
            cpm: 0.10, // Low eCPM for house ads
            currency: "USD",
            fillRate: 1.0 // House ads always fill
        )
    }
    
    private func logAdFill(request: WaterfallAdRequest, response: AdResponse) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("ad_analytics").document().setData([
                "requestId": request.requestId,
                "videoId": request.videoId,
                "source": response.source.rawValue,
                "cpm": response.cpm,
                "fillRate": response.fillRate,
                "placement": request.placement.rawValue,
                "timestamp": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
    
    private func buildCustomParams(request: WaterfallAdRequest) -> String {
        var params: [String] = []
        params.append("vid=\(request.videoId)")
        if let age = request.targeting.age { params.append("age=\(age)") }
        if let gender = request.targeting.gender { params.append("gender=\(gender)") }
        params.append("loc=\(request.targeting.location)")
        return params.joined(separator: "&")
    }
    
    private func extractCreativeURL(from data: Data) -> String? {
        // Parse Ad Manager XML response for creative URL
        if let xml = String(data: data, encoding: .utf8),
           let range = xml.range(of: "<MediaFile[^>]*>([^<]+)</MediaFile>", options: .regularExpression) {
            return String(xml[range])
        }
        return nil
    }
    
    private func extractClickURL(from data: Data) -> String? {
        if let xml = String(data: data, encoding: .utf8),
           let range = xml.range(of: "<ClickThrough[^>]*>([^<]+)</ClickThrough>", options: .regularExpression) {
            return String(xml[range])
        }
        return nil
    }
    
    private func extractImpressionURL(from data: Data) -> String? {
        if let xml = String(data: data, encoding: .utf8),
           let range = xml.range(of: "<Impression[^>]*>([^<]+)</Impression>", options: .regularExpression) {
            return String(xml[range])
        }
        return nil
    }
}

struct WaterfallConfig: Codable {
    let sources: [WaterfallSource]
    let timeout: TimeInterval
    let maxRetries: Int
    
    static let defaultConfig = WaterfallConfig(
        sources: [
            WaterfallSource(type: .direct, priority: 1, timeout: 3.0, floorPrice: 5.0),
            WaterfallSource(type: .admanager, priority: 2, timeout: 2.0, floorPrice: 2.0),
            WaterfallSource(type: .admob, priority: 3, timeout: 2.0, floorPrice: 1.0),
            WaterfallSource(type: .openrtb, priority: 4, timeout: 1.5, floorPrice: 0.5),
            WaterfallSource(type: .house, priority: 5, timeout: 0.1, floorPrice: 0.0)
        ],
        timeout: 5.0,
        maxRetries: 2
    )
}

struct WaterfallSource: Codable {
    let type: AdResponse.AdSource
    let priority: Int
    let timeout: TimeInterval
    let floorPrice: Double
}

// MARK: - OpenRTB Models
struct OpenRTBBidRequest: Codable {
    let id: String
    let imp: [OpenRTBImp]
    let app: OpenRTBApp
    let device: OpenRTBDevice
    let user: OpenRTBUser
}

struct OpenRTBImp: Codable {
    let id: String
    let video: OpenRTBVideo
}

struct OpenRTBVideo: Codable {
    let w: Int
    let h: Int
    let minduration: Int
    let maxduration: Int
    let protocols: [Int]
    let mimes: [String]
}

struct OpenRTBApp: Codable {
    let id: String
    let name: String
    let bundle: String
}

struct OpenRTBDevice: Codable {
    let ua: String
    let ip: String
    let devicetype: Int
    let os: String
}

struct OpenRTBUser: Codable {
    let yob: Int?
    let gender: String?
}

struct OpenRTBBidResponse: Codable {
    let id: String
    let seatbid: [OpenRTBSeatBid]
    let cur: String?
}

struct OpenRTBSeatBid: Codable {
    let bid: [OpenRTBBid]
}

struct OpenRTBBid: Codable {
    let id: String
    let impid: String
    let price: Double
    let adm: String // VAST XML or creative URL
    let nurl: String? // Win notice URL
    let iurl: String? // Impression URL
}
