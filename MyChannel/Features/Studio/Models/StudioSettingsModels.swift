import SwiftUI
import AVKit
import Combine

// MARK: - Supporting Views and Models
struct RevenueCard: View {
    let title: String
    let amount: Double
    let change: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                    .foregroundColor(change >= 0 ? .green : .red)
                Text("\(String(format: "%.1f", abs(change)))%")
                    .foregroundColor(change >= 0 ? .green : .red)
                Text("vs last month")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


// MARK: - Settings Models
struct AdSettings: Equatable {
    var adsEnabled: Bool = false
    var prerollEnabled: Bool = true
    var midrollEnabled: Bool = true
    var postrollEnabled: Bool = false
    var adFrequency: AdFrequency = .medium
    var skippableAds: Bool = true
    var personalizedAds: Bool = true
    
    static func load() -> AdSettings {
        // Load from UserDefaults or backend
        return AdSettings()
    }
    
    func save() {
        // Save to UserDefaults or backend
        UserDefaults.standard.set(adsEnabled, forKey: "ads_enabled")
        UserDefaults.standard.set(prerollEnabled, forKey: "preroll_enabled")
        UserDefaults.standard.set(midrollEnabled, forKey: "midroll_enabled")
        UserDefaults.standard.set(postrollEnabled, forKey: "postroll_enabled")
        UserDefaults.standard.set(skippableAds, forKey: "skippable_ads")
        UserDefaults.standard.set(personalizedAds, forKey: "personalized_ads")
    }
}

enum AdFrequency: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct MembershipSettings {
    var membershipEnabled: Bool = false
    var tiers: [MembershipTier] = []
    
    static func load() -> MembershipSettings {
        return MembershipSettings()
    }
    
    func save() {
        // Save to backend
    }
}

struct MerchandiseSettings {
    var merchandiseEnabled: Bool = false
    var products: [MerchandiseProduct] = []
    
    static func load() -> MerchandiseSettings {
        return MerchandiseSettings()
    }
    
    func save() {
        // Save to backend
    }
}

struct MerchandiseProduct {
    let id: String
    let name: String
    let price: Double
    let imageURL: String
}

