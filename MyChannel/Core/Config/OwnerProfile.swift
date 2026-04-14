import Foundation

struct OwnerProfile {
    static let owner: User = User(
        id: "owner_sbkeonta",
        username: "sbkeonta_",
        displayName: "sbkeonta_",
        email: "owner@mychannel.app"
    )

    // Optional friend list to surface in Top Artists (e.g., IG handles)
    // Only friends with actual local assets (profile images)
    // NOTE: Anyone who appears in the filmmaker or channel section below must NOT appear here
    // to avoid ID collisions (TopRankMLService deduplicates by "ig_<name>" key).
    static let instagramFriends: [FriendArtist] = [

        // ── TOP ARTISTS ──────────────────────────────────────────────────────────
        FriendArtist(name: "HTG Nook",            instagram: "@htg.nook",           avatar: "asset://HTGNookAvatar"),
        FriendArtist(name: "Scatz Ripky",         instagram: "@scatzripky6",         avatar: "asset://ScatzAvatar"),
        FriendArtist(name: "Kleanup Man",         instagram: "@kleanupman__",        avatar: "asset://KleanupManAvatar"),
        FriendArtist(name: "Luh Monti",           instagram: "@luh_monti45",         avatar: "asset://LuhMontiAvatar"),
        FriendArtist(name: "Six Ward Von",        instagram: "@sixwardvon_",         avatar: "asset://SixWardVonAvatar"),
        FriendArtist(name: "Barth Baby",          instagram: "@barthfrmda6ix",       avatar: "asset://BarthBabyAvatar"),
        FriendArtist(name: "2800T Baby",          instagram: "@2800tbaby",           avatar: "asset://2800TBabyAvatar"),
        FriendArtist(name: "Babii Moe",           instagram: "@babiimoe",            avatar: "asset://BabiiMoeAvatar"),
        FriendArtist(name: "Baby Ghost",          instagram: "@babyghost",           avatar: "asset://BabyGhostAvatar"),
        FriendArtist(name: "Bae Shanicee",        instagram: "@baeshanicee",         avatar: "asset://BaeShaniceeAvatar"),
        FriendArtist(name: "BagLife Tee",         instagram: "@baglifetee",          avatar: "asset://BagLifeTeeAvatar"),
        FriendArtist(name: "BandMan",             instagram: "@bandman",             avatar: "asset://BandManAvatar"),
        FriendArtist(name: "Benji Gram",          instagram: "@benjigram",           avatar: "asset://BenjiGramAvatar"),
        FriendArtist(name: "Big Mgr Fat Dee",     instagram: "@bigmgrfatdee",        avatar: "asset://BigMgrFatDeeAvatar"),
        FriendArtist(name: "Bk Dumpp",            instagram: "@bkdumpp",             avatar: "asset://BkDumppAvatar"),
        FriendArtist(name: "Cashpaid Jay",        instagram: "@cashpaidjay",         avatar: "asset://CashpaidJayAvatar"),
        FriendArtist(name: "Cliff King Mac",      instagram: "@cliffkingmac",        avatar: "asset://CliffKingMacAvatar"),
        FriendArtist(name: "Cw Timo",             instagram: "@cwtimo",              avatar: "asset://CwTimoAvatar"),
        FriendArtist(name: "Detwan Love",         instagram: "@detwanlove",          avatar: "asset://DetwanLoveAvatar"),
        FriendArtist(name: "Don Perrion",         instagram: "@donperrion",          avatar: "asset://DonPerrionAvatar"),
        FriendArtist(name: "Faneto Rich",         instagram: "@fanetorich",          avatar: "asset://FanetoRichAvatar"),
        FriendArtist(name: "Fattyrichgang Dell",  instagram: "@fattyrichgangdell",   avatar: "asset://FattyrichgangDellAvatar"),
        FriendArtist(name: "Ftos Twan",           instagram: "@ftostwan",            avatar: "asset://FtosTwanAvatar"),
        FriendArtist(name: "Hotboy Curry",        instagram: "@hotboycurry",         avatar: "asset://HotboyCurryAvatar"),
        FriendArtist(name: "Jeff Skigh",          instagram: "@jeffskigh",           avatar: "asset://JeffSkighAvatar"),
        FriendArtist(name: "Juscallmeep",         instagram: "@juscallmeep",         avatar: "asset://JuscallmeepAvatar"),
        FriendArtist(name: "Kai Edwards",         instagram: "@kaiedwards",          avatar: "asset://KaiEdwardsAvatar"),
        FriendArtist(name: "Krispylife Kidd",     instagram: "@krispylifekidd",      avatar: "asset://KrispylifeKiddAvatar"),
        FriendArtist(name: "Lil Donny",           instagram: "@lildonny",            avatar: "asset://LilDonnyAvatar"),
        FriendArtist(name: "Lsp Manman",          instagram: "@lspmanman",           avatar: "asset://LspManmanAvatar"),
        FriendArtist(name: "Luh Doonie",          instagram: "@luhdoonie",           avatar: "asset://LuhDoonieAvatar"),
        FriendArtist(name: "Luh Sportcoat",       instagram: "@luhsportcoat",        avatar: "asset://LuhSportcoatAvatar"),
        FriendArtist(name: "Mac Quall",           instagram: "@macquall",            avatar: "asset://MacQuallAvatar"),
        FriendArtist(name: "MBK BO Demon",        instagram: "@mbkbodemon",          avatar: "asset://MBKBODemonAvatar"),
        FriendArtist(name: "Mbk Keelan",          instagram: "@mbkkeelan",           avatar: "asset://MbkKeelanAvatar"),
        FriendArtist(name: "MBK Uncle Ruckus",    instagram: "@mbkuncleruckus",      avatar: "asset://MBKUncleRuckusAvatar"),
        FriendArtist(name: "MIA Ghost",           instagram: "@miaghost",            avatar: "asset://MiaGhostAvatar"),
        FriendArtist(name: "Mia Pat Man",         instagram: "@miapatman",           avatar: "asset://MiaPatManAvatar"),
        FriendArtist(name: "Mia Rerock",          instagram: "@miarerock",           avatar: "asset://MiaRerockAvatar"),
        FriendArtist(name: "Rich Dior",           instagram: "@richdior",            avatar: "asset://RichDiorAvatar"),
        FriendArtist(name: "Rlsg KD",             instagram: "@rlsgkd",              avatar: "asset://RlsgKdAvatar"),
        FriendArtist(name: "Savagelife Tank",     instagram: "@savagelifetank",      avatar: "asset://SavagelifeTankAvatar"),
        FriendArtist(name: "Super Shoddy",        instagram: "@supershoddy",         avatar: "asset://SuperShoddyAvatar"),
        FriendArtist(name: "Twyce Marshall",      instagram: "@twycemarshall",       avatar: "asset://TwyceMarshallAvatar"),
        FriendArtist(name: "Way P",               instagram: "@wayp",                avatar: "asset://WayPAvatar"),
        FriendArtist(name: "Yn Jay",              instagram: "@ynjay",               avatar: "asset://YnJayAvatar"),
        FriendArtist(name: "YN Quee",             instagram: "@ynquee",              avatar: "asset://YNQueeAvatar"),
        FriendArtist(name: "Ysr Driveway",        instagram: "@ysrdriveway",         avatar: "asset://YsrDrivewayAvatar"),
        FriendArtist(name: "Ysr Gramz",           instagram: "@ysrgramz",            avatar: "asset://YsrGramzAvatar"),
        FriendArtist(name: "Yung Sak Runner",     instagram: "@yungsakrunner",       avatar: "asset://YungSakRunnerAvatar"),

        // ── TOP INDIE FILMMAKERS ─────────────────────────────────────────────────
        // Shot By Keonta #1, TeeCee #2, Merch HD #3
        FriendArtist(name: "Shot By Keonta", instagram: "@sbkeonta_",  avatar: "asset://ShotByKeontaThumbnail", category: "filmmaker", pinnedRank: 1),
        FriendArtist(name: "TeeCee",         instagram: "@teecee",     avatar: "asset://TeeCeeAvatar",          category: "filmmaker", pinnedRank: 2),
        FriendArtist(name: "Merch HD",       instagram: "@merchhd",    avatar: "asset://MerchHDAvatar",         category: "filmmaker", pinnedRank: 3),
        FriendArtist(name: "Pros KT",        instagram: "@proskt",     avatar: "asset://ProsKtAvatar",          category: "filmmaker", pinnedRank: 4),

        // ── TOP MYCHANNELS ───────────────────────────────────────────────────────
        // Ktrip #1, Baby Ju #2, Mbk Cari #3 — then all artists also appear as channels
        FriendArtist(name: "Ktrip",     instagram: "@ktrip",    avatar: "asset://KtripAvatar",    category: "channel", pinnedRank: 1),
        FriendArtist(name: "Baby Ju",   instagram: "@babyju",   avatar: "asset://BabyJuAvatar",   category: "channel", pinnedRank: 2),
        FriendArtist(name: "Mbk Cari",  instagram: "@mbkcari",  avatar: "asset://MbkCariAvatar",  category: "channel", pinnedRank: 3),
        FriendArtist(name: "HTG Nook_c",        instagram: "@htg.nook",           avatar: "asset://HTGNookAvatar",          category: "channel"),
        FriendArtist(name: "Scatz Ripky_c",     instagram: "@scatzripky6",         avatar: "asset://ScatzAvatar",            category: "channel"),
        FriendArtist(name: "Kleanup Man_c",     instagram: "@kleanupman__",        avatar: "asset://KleanupManAvatar",       category: "channel"),
        FriendArtist(name: "Luh Monti_c",       instagram: "@luh_monti45",         avatar: "asset://LuhMontiAvatar",         category: "channel"),
        FriendArtist(name: "Six Ward Von_c",    instagram: "@sixwardvon_",         avatar: "asset://SixWardVonAvatar",       category: "channel"),
        FriendArtist(name: "Barth Baby_c",      instagram: "@barthfrmda6ix",       avatar: "asset://BarthBabyAvatar",        category: "channel"),
        FriendArtist(name: "2800T Baby_c",      instagram: "@2800tbaby",           avatar: "asset://2800TBabyAvatar",        category: "channel"),
        FriendArtist(name: "Babii Moe_c",       instagram: "@babiimoe",            avatar: "asset://BabiiMoeAvatar",         category: "channel"),
        FriendArtist(name: "Baby Ghost_c",      instagram: "@babyghost",           avatar: "asset://BabyGhostAvatar",        category: "channel"),
        FriendArtist(name: "Bae Shanicee_c",    instagram: "@baeshanicee",         avatar: "asset://BaeShaniceeAvatar",      category: "channel"),
        FriendArtist(name: "BagLife Tee_c",     instagram: "@baglifetee",          avatar: "asset://BagLifeTeeAvatar",       category: "channel"),
        FriendArtist(name: "BandMan_c",         instagram: "@bandman",             avatar: "asset://BandManAvatar",          category: "channel"),
        FriendArtist(name: "Benji Gram_c",      instagram: "@benjigram",           avatar: "asset://BenjiGramAvatar",        category: "channel"),
        FriendArtist(name: "Big Mgr Fat Dee_c", instagram: "@bigmgrfatdee",        avatar: "asset://BigMgrFatDeeAvatar",     category: "channel"),
        FriendArtist(name: "Bk Dumpp_c",        instagram: "@bkdumpp",             avatar: "asset://BkDumppAvatar",          category: "channel"),
        FriendArtist(name: "Cashpaid Jay_c",    instagram: "@cashpaidjay",         avatar: "asset://CashpaidJayAvatar",      category: "channel"),
        FriendArtist(name: "Cliff King Mac_c",  instagram: "@cliffkingmac",        avatar: "asset://CliffKingMacAvatar",     category: "channel"),
        FriendArtist(name: "Cw Timo_c",         instagram: "@cwtimo",              avatar: "asset://CwTimoAvatar",           category: "channel"),
        FriendArtist(name: "Detwan Love_c",     instagram: "@detwanlove",          avatar: "asset://DetwanLoveAvatar",       category: "channel"),
        FriendArtist(name: "Don Perrion_c",     instagram: "@donperrion",          avatar: "asset://DonPerrionAvatar",       category: "channel"),
        FriendArtist(name: "Faneto Rich_c",     instagram: "@fanetorich",          avatar: "asset://FanetoRichAvatar",       category: "channel"),
        FriendArtist(name: "Fattyrichgang Dell_c", instagram: "@fattyrichgangdell", avatar: "asset://FattyrichgangDellAvatar", category: "channel"),
        FriendArtist(name: "Ftos Twan_c",       instagram: "@ftostwan",            avatar: "asset://FtosTwanAvatar",         category: "channel"),
        FriendArtist(name: "Hotboy Curry_c",    instagram: "@hotboycurry",         avatar: "asset://HotboyCurryAvatar",      category: "channel"),
        FriendArtist(name: "Jeff Skigh_c",      instagram: "@jeffskigh",           avatar: "asset://JeffSkighAvatar",        category: "channel"),
        FriendArtist(name: "Juscallmeep_c",     instagram: "@juscallmeep",         avatar: "asset://JuscallmeepAvatar",      category: "channel"),
        FriendArtist(name: "Kai Edwards_c",     instagram: "@kaiedwards",          avatar: "asset://KaiEdwardsAvatar",       category: "channel"),
        FriendArtist(name: "Krispylife Kidd_c", instagram: "@krispylifekidd",      avatar: "asset://KrispylifeKiddAvatar",   category: "channel"),
        FriendArtist(name: "Lil Donny_c",       instagram: "@lildonny",            avatar: "asset://LilDonnyAvatar",         category: "channel"),
        FriendArtist(name: "Lsp Manman_c",      instagram: "@lspmanman",           avatar: "asset://LspManmanAvatar",        category: "channel"),
        FriendArtist(name: "Luh Doonie_c",      instagram: "@luhdoonie",           avatar: "asset://LuhDoonieAvatar",        category: "channel"),
        FriendArtist(name: "Luh Sportcoat_c",   instagram: "@luhsportcoat",        avatar: "asset://LuhSportcoatAvatar",     category: "channel"),
        FriendArtist(name: "Mac Quall_c",       instagram: "@macquall",            avatar: "asset://MacQuallAvatar",         category: "channel"),
        FriendArtist(name: "MBK BO Demon_c",    instagram: "@mbkbodemon",          avatar: "asset://MBKBODemonAvatar",       category: "channel"),
        FriendArtist(name: "Mbk Keelan_c",      instagram: "@mbkkeelan",           avatar: "asset://MbkKeelanAvatar",        category: "channel"),
        FriendArtist(name: "MBK Uncle Ruckus_c", instagram: "@mbkuncleruckus",     avatar: "asset://MBKUncleRuckusAvatar",   category: "channel"),
        FriendArtist(name: "MIA Ghost_c",       instagram: "@miaghost",            avatar: "asset://MiaGhostAvatar",         category: "channel"),
        FriendArtist(name: "Mia Pat Man_c",     instagram: "@miapatman",           avatar: "asset://MiaPatManAvatar",        category: "channel"),
        FriendArtist(name: "Mia Rerock_c",      instagram: "@miarerock",           avatar: "asset://MiaRerockAvatar",        category: "channel"),
        FriendArtist(name: "Rich Dior_c",       instagram: "@richdior",            avatar: "asset://RichDiorAvatar",         category: "channel"),
        FriendArtist(name: "Rlsg KD_c",         instagram: "@rlsgkd",              avatar: "asset://RlsgKdAvatar",           category: "channel"),
        FriendArtist(name: "Savagelife Tank_c", instagram: "@savagelifetank",      avatar: "asset://SavagelifeTankAvatar",   category: "channel"),
        FriendArtist(name: "Super Shoddy_c",    instagram: "@supershoddy",         avatar: "asset://SuperShoddyAvatar",      category: "channel"),
        FriendArtist(name: "Twyce Marshall_c",  instagram: "@twycemarshall",       avatar: "asset://TwyceMarshallAvatar",    category: "channel"),
        FriendArtist(name: "Way P_c",           instagram: "@wayp",                avatar: "asset://WayPAvatar",             category: "channel"),
        FriendArtist(name: "Yn Jay_c",          instagram: "@ynjay",               avatar: "asset://YnJayAvatar",            category: "channel"),
        FriendArtist(name: "YN Quee_c",         instagram: "@ynquee",              avatar: "asset://YNQueeAvatar",           category: "channel"),
        FriendArtist(name: "Ysr Driveway_c",    instagram: "@ysrdriveway",         avatar: "asset://YsrDrivewayAvatar",      category: "channel"),
        FriendArtist(name: "Ysr Gramz_c",       instagram: "@ysrgramz",            avatar: "asset://YsrGramzAvatar",         category: "channel"),
        FriendArtist(name: "Yung Sak Runner_c", instagram: "@yungsakrunner",       avatar: "asset://YungSakRunnerAvatar",    category: "channel"),
    ]
}

struct FriendArtist: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let instagram: String
    let avatar: String
    var category: String = "artist"
    var pinnedRank: Int? = nil  // If set, forces this user to exactly this rank position
}