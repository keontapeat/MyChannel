import SwiftUI
import AVKit

struct AssetStory: Identifiable, Equatable {
    let id: String
    let media: AssetMedia
    let username: String
    let authorImageName: String
    var creatorId: String = ""
    var originalStoryId: String? = nil
    var isCloseFriends: Bool = false

    init(id: String = UUID().uuidString, media: AssetMedia, username: String, authorImageName: String, creatorId: String = "", originalStoryId: String? = nil, isCloseFriends: Bool = false) {
        self.id = originalStoryId ?? id
        self.media = media
        self.username = username
        self.authorImageName = authorImageName
        self.creatorId = creatorId
        self.originalStoryId = originalStoryId
        self.isCloseFriends = isCloseFriends
    }
}

// MARK: - Instagram-style story grouping by user
struct UserStoryGroup: Identifiable {
    let id: String // username lowercased
    let username: String
    let authorImageName: String
    let stories: [AssetStory]
    
    @MainActor
    var isSeen: Bool {
        let seen = StorySeenTracker.shared.seenStoryIds
        return !stories.isEmpty && stories.allSatisfy { seen.contains($0.stableStoryId) }
    }
    
    var hasCloseFriends: Bool {
        stories.contains { $0.isCloseFriends }
    }
    
    static func group(from stories: [AssetStory]) -> [UserStoryGroup] {
        var dict: [String: (username: String, image: String, stories: [AssetStory])] = [:]
        var order: [String] = []
        
        for story in stories {
            let key = story.username.lowercased()
            if dict[key] == nil {
                dict[key] = (username: story.username, image: story.authorImageName, stories: [story])
                order.append(key)
            } else {
                dict[key]?.stories.append(story)
            }
        }
        
        return order.compactMap { key in
            guard let entry = dict[key] else { return nil }
            return UserStoryGroup(
                id: key,
                username: entry.username,
                authorImageName: entry.image,
                stories: entry.stories
            )
        }
    }
    
    /// Sort groups: unseen first, then seen (Instagram ordering)
    @MainActor
    static func sorted(_ groups: [UserStoryGroup]) -> [UserStoryGroup] {
        let unseen = groups.filter { !$0.isSeen }
        let seen = groups.filter { $0.isSeen }
        return unseen + seen
    }
}

enum AssetMedia: Equatable {
    case image(String)
    case video(String)
}

extension AssetStory {
    static var sampleStories: [AssetStory] {
        // Removed sample stories to create authentic experience
        // Users will only see stories from people they actually follow
        []
    }
}

// Matches with HomeView.heroOverlay: id "storyHero-<id>"
struct HeroMatch: ViewModifier {
    let ns: Namespace.ID?
    let id: String

    func body(content: Content) -> some View {
        if let ns {
            content.matchedGeometryEffect(id: "storyHero-\(id)", in: ns)
        } else {
            content
        }
    }
}

// MARK: - Story Bubble (Instagram-style ring)
struct AssetBouncyStoryBubble: View {
    let story: AssetStory
    let isSeen: Bool
    let onTap: (AssetStory) -> Void
    let ns: Namespace.ID?
    let activeHeroId: String?
    let isCurrentUser: Bool

    init(story: AssetStory, isSeen: Bool = false, onTap: @escaping (AssetStory) -> Void, ns: Namespace.ID? = nil, activeHeroId: String? = nil, isCurrentUser: Bool = false) {
        self.story = story
        self.isSeen = isSeen
        self.onTap = onTap
        self.ns = ns
        self.activeHeroId = activeHeroId
        self.isCurrentUser = isCurrentUser
    }

    // Instagram gradient ring colors
    private var ringGradient: LinearGradient {
        if isSeen {
            return LinearGradient(
                colors: [Color(.systemGray4), Color(.systemGray3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if story.isCloseFriends {
            return LinearGradient(
                colors: [Color.green, Color.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.red, .orange, .pink, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            onTap(story)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Instagram-style gradient ring (colored = unseen, gray = seen)
                    Circle()
                        .stroke(ringGradient, lineWidth: isSeen ? 1.5 : 3)
                        .frame(width: 80, height: 80)

                    // White gap between ring and avatar
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 74, height: 74)

                    // Avatar
                    avatarImage
                        .frame(width: 68, height: 68)
                        .clipShape(Circle())
                }
                .opacity(activeHeroId == story.id ? 0 : 1)
                .modifier(HeroMatch(ns: ns, id: story.id))

                Text(isCurrentUser ? "Your story" : story.username)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 80)
            }
            .frame(width: 88, height: 124)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("\(story.username) story")
        .accessibilityAddTraits(.isButton)
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        if let remoteURL = URL(string: story.authorImageName), remoteURL.scheme == "https" || remoteURL.scheme == "http" {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    ZStack {
                        LinearGradient(
                            colors: [.blue.opacity(0.28), .purple.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(String(story.username.prefix(2)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        } else if let uiImage = UIImage(named: story.authorImageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.28), .purple.opacity(0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(String(story.username.prefix(2)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Stories Row
struct AssetBouncyStoriesRow: View {
    let stories: [AssetStory]
    let onStoryTap: (AssetStory) -> Void
    let onAddStory: () -> Void
    let ns: Namespace.ID?
    let activeHeroId: String?
    @ObservedObject private var seenTracker = StorySeenTracker.shared

    init(
        stories: [AssetStory],
        onStoryTap: @escaping (AssetStory) -> Void,
        onAddStory: @escaping () -> Void,
        ns: Namespace.ID? = nil,
        activeHeroId: String? = nil
    ) {
        self.stories = stories
        self.onStoryTap = onStoryTap
        self.onAddStory = onAddStory
        self.ns = ns
        self.activeHeroId = activeHeroId
    }

    // Group stories by user, one bubble per user (Instagram-style)
    private var userGroups: [UserStoryGroup] {
        let groups = UserStoryGroup.group(from: stories)
        return UserStoryGroup.sorted(groups)
    }

    private var currentUserId: String? {
        AppState.shared.currentUser?.id
    }

    private var currentUserGroup: UserStoryGroup? {
        guard let currentUserId else { return nil }
        return userGroups.first(where: { group in
            group.stories.contains(where: { $0.creatorId == currentUserId })
        })
    }

    private var nonCurrentUserGroups: [UserStoryGroup] {
        guard let currentUserId else { return userGroups }
        return userGroups.filter { group in
            !group.stories.contains(where: { $0.creatorId == currentUserId })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    leadingStoryButton
                        .padding(.leading, 20)

                    ForEach(nonCurrentUserGroups) { group in
                        // Show the first story as the representative bubble for this user
                        if let representative = group.stories.first {
                            AssetBouncyStoryBubble(
                                story: representative,
                                isSeen: group.isSeen,
                                onTap: onStoryTap,
                                ns: ns,
                                activeHeroId: activeHeroId
                            )
                            .id(group.id)
                            .contentShape(Rectangle())
                        }
                    }

                    Color.clear.frame(width: 20)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
        }
        .background(AppTheme.Colors.background)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingStoryButton: some View {
        if let currentUserGroup, let representative = currentUserGroup.stories.first {
            AssetBouncyStoryBubble(
                story: representative,
                isSeen: currentUserGroup.isSeen,
                onTap: onStoryTap,
                ns: ns,
                activeHeroId: activeHeroId,
                isCurrentUser: true
            )
            .accessibilityLabel("Your story")
        } else {
            addStoryButton
        }
    }

    private var addStoryButton: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onAddStory()
        }) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 74, height: 74)
                        .overlay(
                            ProfileAvatarView(
                                urlString: getUserProfileImageURL(),
                                size: 68
                            )
                            .clipShape(Circle())
                        )
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                        )

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 3)
                        )
                        .offset(x: 2, y: 2)
                }
                .frame(width: 80, height: 80)

                Text("Your story")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(width: 80)
            }
            .frame(width: 88, height: 124)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("Add your story")
    }
    
    // 🔥 Get current user's profile picture
    private func getUserProfileImageURL() -> String {
        AppState.shared.currentUser?.profileImageURL ?? ""
    }
}

extension AssetStory {
    var stableStoryId: String {
        originalStoryId ?? id
    }
}

// STORY VIEWER
struct AssetStoryViewerView: View {
    let story: AssetStory
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch story.media {
        case .image(let name):
            if let remoteURL = URL(string: name), remoteURL.scheme == "https" || remoteURL.scheme == "http" {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        ZStack {
                            Color.black
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    case .empty:
                        ZStack {
                            Color.black
                            ProgressView().tint(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        case .video(let resource):
            if let remoteURL = URL(string: resource), remoteURL.scheme == "https" || remoteURL.scheme == "http" {
                RawPlayerLayerView(player: AVPlayer(url: remoteURL), videoGravity: .resizeAspectFill)
                    .ignoresSafeArea()
            } else if let url = Bundle.main.url(forResource: resource, withExtension: nil) {
                RawPlayerLayerView(player: AVPlayer(url: url), videoGravity: .resizeAspectFill)
                    .ignoresSafeArea()
            } else {
                Text("Video not found").foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Previews
#Preview("Clean Story Bubble") {
    VStack {
        AssetBouncyStoryBubble(
            story: AssetStory.sampleStories.first!,
            onTap: { _ in },
            ns: nil,
            activeHeroId: nil
        )
    }
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("Clean Stories Row") {
    VStack {
        AssetBouncyStoriesRow(
            stories: AssetStory.sampleStories,
            onStoryTap: { _ in },
            onAddStory: {},
            ns: nil,
            activeHeroId: nil
        )
    }
    .padding(.vertical)
    .background(AppTheme.Colors.background)
}

#Preview("Story Viewer") {
    AssetStoryViewerView(
        story: AssetStory.sampleStories.first!,
        onDismiss: {}
    )
}
