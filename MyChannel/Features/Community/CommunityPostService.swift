import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Using CommunityPost from Core/Models/Community.swift

@MainActor
final class CommunityPostService: ObservableObject {
    static let shared = CommunityPostService()
    private init() {}
    
    @Published var posts: [CommunityPost] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    #endif
    
    func listenToPosts(creatorId: String) {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = db.collection("community_posts")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.posts = docs.compactMap { doc in
                    let d = doc.data()
                    let poll: Poll?
                    if let pollData = d["poll"] as? [String: Any] {
                        poll = Poll(
                            question: pollData["question"] as? String ?? "",
                            options: (pollData["options"] as? [[String: Any]] ?? []).compactMap { opt in
                                PollOption(
                                    text: opt["text"] as? String ?? "",
                                    voteCount: opt["voteCount"] as? Int ?? 0
                                )
                            }
                        )
                    } else {
                        poll = nil
                    }
                    
                    return CommunityPost(
                        id: doc.documentID,
                        creatorId: d["creatorId"] as? String ?? "",
                        content: d["content"] as? String ?? "",
                        imageURLs: d["imageURL"] as? String != nil ? [d["imageURL"] as! String] : [],
                        videoURL: nil,
                        postType: PostType(rawValue: d["type"] as? String ?? "text") ?? .text,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        updatedAt: Date(),
                        likeCount: d["likeCount"] as? Int ?? 0,
                        commentCount: d["commentCount"] as? Int ?? 0,
                        shareCount: 0,
                        isPinned: false,
                        isEdited: false,
                        poll: poll,
                        tags: []
                    )
                }
            }
        #endif
        
        // Mock fallback
        if posts.isEmpty {
            posts = generateMockPosts(creatorId: creatorId)
        }
    }
    
    func createPost(creatorId: String, type: PostType, content: String, imageURL: String? = nil, poll: Poll? = nil) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("community_posts").document()
            var data: [String: Any] = [
                "creatorId": creatorId,
                "type": type.rawValue,
                "content": content,
                "likeCount": 0,
                "commentCount": 0,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let imageURL = imageURL { data["imageURL"] = imageURL }
            if let poll = poll {
                data["poll"] = [
                    "question": poll.question,
                    "options": poll.options.map { ["text": $0.text, "voteCount": $0.voteCount] },
                    "totalVotes": poll.totalVotes
                ]
            }
            try await ref.setData(data)
            return ref.documentID
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func toggleLike(postId: String, userId: String, add: Bool) async {
        #if canImport(FirebaseFirestore)
        let likesRef = db.collection("community_posts").document(postId).collection("likes").document(userId)
        do {
            if add {
                try await likesRef.setData(["likedAt": FieldValue.serverTimestamp()])
            } else {
                try await likesRef.delete()
            }
        } catch { }
        #endif
    }
    
    func votePoll(postId: String, userId: String, optionIndex: Int) async {
        #if canImport(FirebaseFirestore)
        let voteRef = db.collection("community_posts").document(postId).collection("votes").document(userId)
        do {
            try await voteRef.setData([
                "optionIndex": optionIndex,
                "votedAt": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
    
    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }
    
    private func generateMockPosts(creatorId: String) -> [CommunityPost] {
        return [
            CommunityPost(
                id: "post1",
                creatorId: creatorId,
                content: "Just finished editing my latest video! Can't wait for you all to see it 🎬",
                imageURLs: [],
                postType: .text,
                createdAt: Date().addingTimeInterval(-3600),
                likeCount: 245,
                commentCount: 18
            ),
            CommunityPost(
                id: "post2", 
                creatorId: creatorId,
                content: "What should my next video be about?",
                imageURLs: [],
                postType: .poll,
                createdAt: Date().addingTimeInterval(-7200),
                likeCount: 89,
                commentCount: 42,
                poll: Poll(
                    question: "What should my next video be about?",
                    options: [
                        PollOption(text: "Tech Review", voteCount: 120),
                        PollOption(text: "Gaming", voteCount: 89),
                        PollOption(text: "Tutorial", voteCount: 156),
                        PollOption(text: "Vlog", voteCount: 45)
                    ]
                )
            ),
            CommunityPost(
                id: "post3",
                creatorId: creatorId,
                content: "Behind the scenes from today's shoot! 📸",
                imageURLs: ["https://picsum.photos/800/600?random=1"],
                postType: .image,
                createdAt: Date().addingTimeInterval(-14400),
                likeCount: 178,
                commentCount: 25
            )
        ]
    }
}
