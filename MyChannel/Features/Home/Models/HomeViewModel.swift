import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class HomeViewModel: ObservableObject {
    @Published var miniActive = false
    @Published var scrollOffset: CGFloat = 0
    @Published var isRefreshing: Bool = false
    
    // Routing state
    @Published var route: FullScreenRoute? = nil
    @Published var showingQuickProfile = false
    @Published var showingSettings = false
    @Published var showingSwitchProfile = false
    @Published var showingFeaturedManager = false
    @Published var showingEditProfile = false

    // Pending action to run AFTER the quick profile sheet finishes dismissing.
    // This avoids the old `Task.sleep` + NotificationCenter round-trip and the
    // racy "present a sheet while another is still dismissing" problem.
    @Published var pendingQuickProfileAction: QuickProfileAction? = nil

    enum QuickProfileAction {
        case creatorStudio
        case viewChannel
        case settings
        case switchProfile
        case editProfile
        case analytics
    }
    
    // Featured content
    @Published var featuredContent: [Video] = []
    @Published var heroVideoIndex: Int = 0
    
    // Stories
    @Published var showingStories: Bool = true
    @Published var assetStories: [AssetStory] = []
    @Published var allAssetStories: [AssetStory] = []
    @Published var presentStoryCreator: Bool = false
    
    // Filters
    @Published var selectedHomeChip: HomeFilterChip = .all
    
    // Infinite Scroll Feed
    @Published var feedVideos: [Video] = []
    @Published var isLoadingFeed: Bool = false
    #if canImport(FirebaseFirestore)
    private var lastDocument: DocumentSnapshot? = nil
    #endif
    private var hasMoreVideos: Bool = true
    
    func fetchFeedVideos(refresh: Bool = false) async {
        guard !isLoadingFeed else { return }
        if refresh {
            feedVideos = []
            #if canImport(FirebaseFirestore)
            lastDocument = nil
            #endif
            hasMoreVideos = true
        }
        guard hasMoreVideos else { return }
        
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        
        #if canImport(FirebaseFirestore)
        do {
            var query: Query = Firestore.firestore().collection("videos")
                .whereField("isPublic", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
            
            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }
            
            let snap = try await query.getDocuments()
            if snap.documents.count < 10 {
                hasMoreVideos = false
            }
            lastDocument = snap.documents.last
            
            var newVideos: [Video] = []
            for doc in snap.documents {
                let d = doc.data()
                
                // Construct basic creator info if needed
                let creatorId = d["userId"] as? String ?? ""
                let embeddedName = d["creatorDisplayName"] as? String ?? d["creatorName"] as? String ?? "Creator"
                let creator = User(
                    id: creatorId,
                    username: d["creatorUsername"] as? String ?? "user",
                    displayName: embeddedName,
                    email: "",
                    profileImageURL: d["creatorProfileImage"] as? String ?? d["creatorAvatarURL"] as? String,
                    bannerImageURL: nil,
                    bio: nil,
                    subscriberCount: 0,
                    videoCount: 0,
                    isVerified: (d["creatorVerified"] as? Bool) ?? false,
                    isCreator: true,
                    createdAt: Date()
                )
                
                let rawVideoUrl = (d["videoUrl"] as? String) ?? (d["videoURL"] as? String) ?? ""
                let video = Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? d["thumbnailURL"] as? String ?? "",
                    videoURL: rawVideoUrl,
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: (d["viewCount"] as? Int) ?? 0,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: creator,
                    category: VideoCategory(rawValue: d["category"] as? String ?? "") ?? .entertainment,
                    tags: (d["tags"] as? [String]) ?? [],
                    isPublic: true,
                    visibility: .public
                )
                newVideos.append(video)
            }
            
            // 🔥 Phase 112: Feed Autopilot Reranking
            if let currentUserId = AuthenticationManager.shared.currentUser?.id {
                if let rerankedSlots = try? await FeedAutopilotService.shared.rerank(
                    currentFeed: newVideos.enumerated().map { FeedSlot(id: $0.element.id, position: $0.offset, predictedSatisfaction: 0.5, source: .personalized) },
                    userId: currentUserId
                ) {
                    let videoDict = Dictionary(uniqueKeysWithValues: newVideos.map { ($0.id, $0) })
                    newVideos = rerankedSlots.compactMap { videoDict[$0.id] }
                }
                
                // Phase 111: Session Graph Recommendations
                try? await SessionGraphRecommenderService.shared.recommend(userId: currentUserId, count: 5)
                let recommendedIds = SessionGraphRecommenderService.shared.recommendations.map { $0.id }
                // In a real app we'd fetch these recommended videos and inject them, but for now we just trigger the engine.
            }
            
            self.feedVideos.append(contentsOf: newVideos)
        } catch {
            print("🚨 [HomeViewModel] Error fetching feed videos: \(error)")
        }
        #endif
    }
}
