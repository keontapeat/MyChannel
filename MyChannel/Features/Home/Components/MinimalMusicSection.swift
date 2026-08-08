import SwiftUI
import Combine

// MARK: - Music Section (Artists Carousel)
struct MinimalMusicSection: View {
    var onOpenArtistMusicProfile: (CatalogArtist) -> Void
    @EnvironmentObject var appState: AppState
    var onSeeAll: (() -> Void)? = nil
    
    // Artist name → Apple Music ID mapping for navigation
    private static let artistAppleMusicIds: [String: Int] = [
        "Lil Donny": 1857859662,
        "MIA Ghost": 1582746406,
        "Mia Ghost": 1582746406,
        "Mia Getem": 1798000837,
        "Bk Dumpp": 1709296525,
        "Hotboy Curry": 1771099410,
        "Ysr Loski": 1511351716,
        "Luh Monti": 1656612386,
        "Luh monti": 1656612386,
        "Babyfxce E": 1573432856,
        "3200 Tre": 1491631657,
        "Ktrip": 1484873437,
        "KTrip": 1484873437,
        "Báby Ju": 1649723396,
        "Baby Ju": 1649723396,
        "Ftos Twan": 1527300992,
        "FTOS Twan": 1527300992,
        "Scatz": 904008025,
        "Scatz Ripky": 904008025,
        "Baby Ghost": 1507813989,
        "Way P": 1524383650,
        "Yn Jay": 1482962180,
        "YN Jay": 1482962180,
        "Krispylife Kidd": 1477569694,
        "KrispyLife Kidd": 1477569694,
        "Clean Up Man": 1538452293,
        "Eightball Tank": 1492591865,
        "Ysr Gramz": 1490787471,
        "YSR Gramz": 1490787471,
        "Babii Moe": 1507109510,
        "Babii MOE": 1507109510,
        "Six Ward Von": 1564317122,
        "MIA Patman": 1548074075,
        "Mia PatMan": 1548074075,
        "Mia Pat Man": 1548074075,
        "Lil Nook": 1763508797,
        "lil nook": 1763508797,
        "Jeff Skigh": 945119824,
        "Homi Michel": 1514456557,
        "BBDR Tay": 1501537814,
        "PaidLife Zar": 1501538060,
        "Paidlife Zar": 1501538060,
        "Richvon23": 1531986560,
        "RichVon23": 1531986560,
        "Geeoutto": 1583072463,
        "Mia Curt": 1576989709,
        "Dee Grant": 1488384274,
        "FTM Bear": 1483982707,
        "Ftm Bear": 1483982707,
        "Cliff Mac": 964080263,
        "Obabe": 1496302013,
        "Velly Beretta": 1174001237,
        "King Cashes": 1498000463,
        "King cashes": 1498000463,
        "Detwan Love": 1155696158,
        "Real JT": 1422427461,
        "real jt": 1422427461,
        "Realjt": 1422427461,
        "Lil Lik": 1725106609,
        "Lil lik": 1725106609,
        "Stickz": 1676978658,
        "MANNYKEA": 1828612897,
        "Mannykea": 1828612897,
        "Ot Love": 1836358576,
        "OT Love": 1836358576,
    ]
    
    private func catalogArtistFor(name: String, avatar: String) -> CatalogArtist {
        let appleMusicId = Self.artistAppleMusicIds[name] ?? abs(name.hashValue % 9_000_000 + 1_000_000)
        let artworkUrl: String?
        if avatar.hasPrefix("http") {
            artworkUrl = avatar
        } else if let _ = UIImage(named: avatar) {
            artworkUrl = "asset://\(avatar)"
        } else {
            artworkUrl = nil
        }
        return CatalogArtist(
            id: appleMusicId,
            name: name,
            linkUrl: "https://music.apple.com/us/artist/\(appleMusicId)",
            artworkUrl: artworkUrl
        )
    }

    private var allArtists: [(name: String, avatar: String, views: Int, city: String?)] {
        // 🎵 LOCAL ARTISTS WITH ASSETS - Using local images for fast loading!
        let localArtists: [(String,String,Int,String?)] = [
            ("Ysr Gramz", "YsrGramzAvatar", 290_000, nil),
            ("Krispylife Kidd", "KrispylifeKiddAvatar", 288_000, nil),
            ("Kleanup Man", "KleanupManAvatar", 287_000, "Detroit, MI"),
            ("Lil Donny", "LilDonnyAvatar", 286_000, nil),
            ("Big Mgr Fat Dee", "BigMgrFatDeeAvatar", 285_000, nil),
            ("Bk Dumpp", "BkDumppAvatar", 285_000, nil),
            ("Super Shoddy", "SuperShoddyAvatar", 285_000, nil),
            ("Mbk Keelan", "MbkKeelanAvatar", 285_000, nil),
            ("Cw Timo", "CwTimoAvatar", 285_000, nil),
            ("Fattyrichgang Dell", "FattyrichgangDellAvatar", 285_000, nil),
            ("BagLife Tee", "BagLifeTeeAvatar", 285_000, nil),
            ("Kai Edwards", "KaiEdwardsAvatar", 285_000, nil),
            ("Mia PatMan", "MiaPatManAvatar", 285_000, nil),
            ("Yung Sak Runner", "YungSakRunnerAvatar", 285_000, nil),
            ("Don Perrion", "DonPerrionAvatar", 285_000, nil),
            ("Way P", "WayPAvatar", 285_000, nil),
            ("Ysr Driveway", "YsrDrivewayAvatar", 285_000, nil),
            ("Babii Moe", "BabiiMoeAvatar", 285_000, nil),
            ("Rich Dior", "RichDiorAvatar", 285_000, nil),
            ("MBK BO Demon", "MBKBODemonAvatar", 285_000, nil),
            ("MBK Uncle Ruckus", "MBKUncleRuckusAvatar", 285_000, nil),
            ("Ktrip", "KtripAvatar", 285_000, nil),
            ("Cliff King Mac", "CliffKingMacAvatar", 285_000, nil),
            ("Mia Rerock", "MiaRerockAvatar", 285_000, nil),
            ("Juscallmeep", "JuscallmeepAvatar", 285_000, nil),
            ("Rlsg Kd", "RlsgKdAvatar", 285_000, nil),
            ("Yn Jay", "YnJayAvatar", 285_000, nil),
            ("YN Quee", "YNQueeAvatar", 285_000, nil),
            ("Detwan Love", "DetwanLoveAvatar", 285_000, nil),
            ("Savagelife Tank", "SavagelifeTankAvatar", 285_000, nil),
            ("Mia Ghost", "MiaGhostAvatar", 285_000, nil),
            ("2800 TBaby", "2800TBabyAvatar", 285_000, nil),
            ("Luh Sportcoat", "LuhSportcoatAvatar", 285_000, nil),
            ("Ftos Twan", "FtosTwanAvatar", 285_000, nil),
            ("Hotboy Curry", "HotboyCurryAvatar", 285_000, nil),
            ("Twyce Marshall", "TwyceMarshallAvatar", 275_000, nil),
            ("Bae Shanicee", "BaeShaniceeAvatar", 200_000, nil),
            ("Báby Ju", "BabyJuAvatar", 210_000, nil),
            ("HTG Nook", "HTGNookAvatar", 215_600, "Flint, MI"),
            ("Scatz Ripky", "ScatzAvatar", 346_300, "Flint, MI"),
            ("Faneto Rich", "FanetoRichAvatar", 250_000, "Buc Town"),
            ("Cashpaid Jay", "CashpaidJayAvatar", 225_000, nil),
            ("Benji Gram", "BenjiGramAvatar", 220_000, nil),
            ("Mbk Cari", "MbkCariAvatar", 195_000, nil),
            ("Luh Monti", "LuhMontiAvatar", 230_000, nil),
            ("Mac Quall", "MacQuallAvatar", 205_000, nil),
            ("Jeff Skigh", "JeffSkighAvatar", 200_000, nil),
            ("Six Ward Von", "SixWardVonAvatar", 210_000, nil),
            ("Barth Baby", "BarthBabyAvatar", 215_000, nil),
            ("Baby Ghost", "BabyGhostAvatar", 220_000, nil)
        ]
        
        let curated: [(String,String,Int,String?)] = OwnerProfile.instagramFriends.map { ($0.name, $0.avatar, Int.random(in: 50_000...350_000), nil) }
        
        // Improved deduplication: normalize names (remove @, spaces, punctuation) and check avatar assets
        var seen = Set<String>()
        var seenAvatars = Set<String>()
        var ordered: [(String,String,Int,String?)] = []
        
        // Helper to normalize artist name for comparison
        func normalize(_ name: String) -> String {
            return name.lowercased()
                .replacingOccurrences(of: "@", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
        }
        
        // Helper to extract asset name from avatar string
        func extractAssetName(_ avatar: String) -> String? {
            if avatar.hasPrefix("asset://") {
                let components = avatar.components(separatedBy: "?")
                if components.count > 0 {
                    return components[0].replacingOccurrences(of: "asset://", with: "")
                }
            } else if !avatar.hasPrefix("http") {
                // Local asset name (not a URL)
                return avatar
            }
            return nil
        }
        
        // Process local artists first (priority)
        for item in localArtists {
            let normalizedName = normalize(item.0)
            let assetName = extractAssetName(item.1)
            
            // Skip if we've already seen this normalized name or the same asset
            let shouldSkip = seen.contains(normalizedName) || (assetName != nil && seenAvatars.contains(assetName!))
            if !shouldSkip {
                seen.insert(normalizedName)
                if let asset = assetName {
                    seenAvatars.insert(asset)
                }
                ordered.append(item)
            }
        }
        
        // Then add curated artists (skip if duplicate)
        for item in curated {
            let normalizedName = normalize(item.0)
            let assetName = extractAssetName(item.1)
            
            // Skip if duplicate name or asset
            let shouldSkip = seen.contains(normalizedName) || (assetName != nil && seenAvatars.contains(assetName!))
            if !shouldSkip {
                seen.insert(normalizedName)
                if let asset = assetName {
                    seenAvatars.insert(asset)
                }
                ordered.append(item)
            }
        }
        
        return ordered
    }

    private var artists: [(name: String, avatar: String, views: Int, city: String?)] {
        // Allow all artists - UI will show fallback if image doesn't exist
        allArtists
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Music")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                Spacer()
                if let onSeeAll {
                    Button("See all", action: onSeeAll)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(artists.enumerated()), id: \.offset) { _, a in
                        Button {
                            let artist = catalogArtistFor(name: a.name, avatar: a.avatar)
                            onOpenArtistMusicProfile(artist)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                // Check if it's a local asset or URL
                                if a.avatar.hasPrefix("http") {
                                    AppAsyncImage(url: URL(string: a.avatar)) { img in
                                        img
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.systemGray6))
                                            .frame(width: 120, height: 180)
                                    }
                                } else {
                                    // Local asset image with fallback
                                    Group {
                                        if let uiImage = UIImage(named: a.avatar) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 180)
                                                .offset(y: a.avatar == "MbkCariAvatar" ? 15 : 0) // Shift Mbk Cari image down to show face
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        } else {
                                            // Fallback placeholder if asset not found
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(.systemGray5), Color(.systemGray6)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 120, height: 180)
                                                .overlay(
                                                    Image(systemName: "person.circle.fill")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.secondary)
                                                )
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                    Text("\(format(a.views)) total views")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }
}
