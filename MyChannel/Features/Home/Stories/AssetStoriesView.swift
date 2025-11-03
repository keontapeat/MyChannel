import SwiftUI
import AVKit

struct AssetStory: Identifiable, Equatable {
    let id = UUID()
    let media: AssetMedia
    let username: String
    let authorImageName: String
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

// MARK: - Story Bubble
struct AssetBouncyStoryBubble: View {
    let story: AssetStory
    let onTap: (AssetStory) -> Void
    let ns: Namespace.ID?
    let activeHeroId: UUID?

    init(story: AssetStory, onTap: @escaping (AssetStory) -> Void, ns: Namespace.ID? = nil, activeHeroId: UUID? = nil) {
        self.story = story
        self.onTap = onTap
        self.ns = ns
        self.activeHeroId = activeHeroId
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            onTap(story)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)

                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 74, height: 74)
                        .overlay(
                            Group {
                                if let uiImage = UIImage(named: story.authorImageName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 74, height: 74)
                                        .clipShape(Circle())
                                } else {
                                    ZStack {
                                        LinearGradient(
                                            colors: [.blue.opacity(0.28), .purple.opacity(0.28)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        Text(String(story.username.prefix(2)).uppercased())
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 74, height: 74)
                                    .clipShape(Circle())
                                }
                            }
                        )

                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 80, height: 80)
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
}

// MARK: - Stories Row
struct AssetBouncyStoriesRow: View {
    let stories: [AssetStory]
    let onStoryTap: (AssetStory) -> Void
    let onAddStory: () -> Void
    let ns: Namespace.ID?
    let activeHeroId: UUID?

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

                    ForEach(stories) { story in
                        AssetBouncyStoryBubble(
                            story: story,
                            onTap: onStoryTap,
                            ns: ns,
                            activeHeroId: activeHeroId
                        )
                        .id(story.id)
                        .contentShape(Rectangle())
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
                ZStack {
                    // 🔥 INSTAGRAM/FACEBOOK PARITY: Gradient Ring
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.38, blue: 0.38),
                                    Color(red: 0.98, green: 0.55, blue: 0.25),
                                    Color(red: 0.85, green: 0.26, blue: 0.86),
                                    Color(red: 0.53, green: 0.36, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)
                        .shadow(color: Color(red: 0.85, green: 0.26, blue: 0.86).opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    // White border
                    Circle()
                        .fill(Color.white)
                        .frame(width: 76, height: 76)
                    
                    // 🔥 USER'S PROFILE PICTURE (like Instagram)
                    ProfileAvatarView(
                        urlString: getUserProfileImageURL(),
                        size: 70
                    )
                    .clipShape(Circle())
                    
                    // 🔥 Plus Button Overlay (bottom-right corner like Instagram)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.85, green: 0.26, blue: 0.86),
                                                Color(red: 0.53, green: 0.36, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 28)
                                    .shadow(color: Color(red: 0.85, green: 0.26, blue: 0.86).opacity(0.5), radius: 4, x: 0, y: 2)
                                
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 4, y: 4)
                        }
                    }
                    .frame(width: 82, height: 82)
                }
                
                // 🔥 Better text styling like Instagram
                Text("Your story")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
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
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        case .video(let resource):
            if let url = Bundle.main.url(forResource: resource, withExtension: nil) {
                VideoPlayer(player: AVPlayer(url: url))
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
