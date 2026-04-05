import SwiftUI
import AVKit

struct AssetStory: Identifiable, Equatable {
    let id = UUID()
    let media: AssetMedia
    let username: String
    let authorImageName: String
    var creatorId: String = ""
    var originalStoryId: String? = nil
}

// MARK: - Instagram-style story grouping by user
struct UserStoryGroup: Identifiable {
    let id: String // username lowercased
    let username: String
    let authorImageName: String
    let stories: [AssetStory]
    
    var isSeen: Bool {
        StorySeenTracker.shared.seenUsernames.contains(username.lowercased())
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

// Matches with HomeView.heroOverlay: id "storyHero-<uuid>"
struct HeroMatch: ViewModifier {
    let ns: Namespace.ID?
    let id: UUID

    func body(content: Content) -> some View {
        if let ns {
            content.matchedGeometryEffect(id: "storyHero-\(id.uuidString)", in: ns)
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
    let activeHeroId: UUID?

    init(story: AssetStory, isSeen: Bool = false, onTap: @escaping (AssetStory) -> Void, ns: Namespace.ID? = nil, activeHeroId: UUID? = nil) {
        self.story = story
        self.isSeen = isSeen
        self.onTap = onTap
        self.ns = ns
        self.activeHeroId = activeHeroId
    }

    // Instagram gradient ring colors
    private var ringGradient: LinearGradient {
        if isSeen {
            return LinearGradient(
                colors: [Color(.systemGray4), Color(.systemGray3)],
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

                Text(story.username)
                    .font(.system(size: 12, weight: .semibold))
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
    let activeHeroId: UUID?
    @ObservedObject private var seenTracker = StorySeenTracker.shared

    init(
        stories: [AssetStory],
        onStoryTap: @escaping (AssetStory) -> Void,
        onAddStory: @escaping () -> Void,
        ns: Namespace.ID? = nil,
        activeHeroId: UUID? = nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    addStoryButton
                        .padding(.leading, 20)

                    ForEach(userGroups) { group in
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

    private var addStoryButton: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onAddStory()
        }) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 78, height: 78)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            ProfileAvatarView(
                                urlString: getUserProfileImageURL(),
                                size: 72
                            )
                            .clipShape(Circle())
                        )
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.divider, lineWidth: 1.5)
                        )

                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 6, y: 6)
                }

                Text("Create story")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
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
        // Fetch from AppState when available
        // For now, return empty string and ProfileAvatarView will show initials
        ""
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
