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
        [
            AssetStory(media: .image("470923123_18158490016332148_6477017450217403765_n"), username: "luh_monti45", authorImageName: "472855250_1416699136402148_2912796090052603733_n"),
            AssetStory(media: .image("466399531_2282738375443632_7939875496433451873_n"), username: "geefrm2800", authorImageName: "475835447_675201954830347_1756031358478369730_n"),
            AssetStory(media: .image("481384467_18341497597158210_3083149182286552212_n"), username: "reformedscumbag", authorImageName: "481160706_665641712649483_7487614386252000095_n"),
            AssetStory(media: .image("472504500_1101976318379746_2397090296561515486_n"), username: "riodayung0g", authorImageName: "472955542_1108862347600211_1464147699689809610_n"),
            AssetStory(media: .image("471582924_1671310553792033_5742790187970581156_n"), username: "ynjay_", authorImageName: "470893866_3028638620618688_1265238229893490157_n"),
            AssetStory(media: .image("472392893_18252867850302322_7284995541774475779_n"), username: "rmc__mike", authorImageName: "334320756_533260078924966_5316833915723430997_n"),
            AssetStory(media: .image("472432520_18472642246031137_3508869297850106955_n"), username: "mineentertainmentllc", authorImageName: "481160706_665641712649483_7487614386252000095_n"),
            AssetStory(media: .image("129075787_113795503889280_2510749229606017551_n"), username: "bighornetpro", authorImageName: "426685704_792648982704647_967197470146596162_n"),
            AssetStory(media: .image("475362444_18498481846042375_7590792999184552048_n"), username: "3200tre", authorImageName: "462248242_560040823136600_3556568014350287952_n"),
            AssetStory(media: .image("friend_post2"), username: "bopfrm2800", authorImageName: "friend_profile2"),
            AssetStory(media: .image("TLC-My-600-Lb-Life"), username: "head_finder", authorImageName: "friend_profile4"),
            AssetStory(media: .image("465660700_1797636381041731_4081532569943287856_n"), username: "freeemweemseeemleaveem", authorImageName: "457371595_1235198240853217_1778504049849463165_n"),
            AssetStory(media: .image("469432783_1093903885799534_1724252623959748153_n"), username: "scatzripky6", authorImageName: "481403833_944554144430511_4402918744878259452_n"),
            AssetStory(media: .image("414116176_18403337470029368_4671543000983622132_n"), username: "kleanupman__", authorImageName: "friend_post3"),
            AssetStory(media: .image("479671664_18355134121123741_7935412116944760137_n"), username: "official.wayp", authorImageName: "friend_profile5")
        ]
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

// 🔥 CLEAN & MINIMAL STORY BUBBLE - WHITE DESIGN LIKE PROFILE IMAGE
struct AssetBouncyStoryBubble: View {
    let story: AssetStory
    let onTap: (AssetStory) -> Void
    let ns: Namespace.ID?
    let activeHeroId: UUID?

    @State private var isPressed = false

    init(story: AssetStory, onTap: @escaping (AssetStory) -> Void, ns: Namespace.ID? = nil, activeHeroId: UUID? = nil) {
        self.story = story
        self.onTap = onTap
        self.ns = ns
        self.activeHeroId = activeHeroId
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: { 
                onTap(story)
                HapticManager.shared.impact(style: .light)
            }) {
                ZStack {
                    // 🔥 CLEAN WHITE RING (LIKE PROFILE IMAGE)
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    // CLEAN PROFILE IMAGE
                    AsyncImage(url: URL(string: "https://picsum.photos/200/200?random=\(story.id.hashValue)")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                    } placeholder: {
                        // Fallback to local image
                        Image(story.authorImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                    }
                }
                .opacity(activeHeroId == story.id ? 0 : 1)
                .modifier(HeroMatch(ns: ns, id: story.id))
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }
            .buttonStyle(PlainButtonStyle())
            .onPressGesture(
                onPress: { isPressed = true },
                onRelease: { isPressed = false }
            )

            // CLEAN USERNAME
            Text(story.username)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 80)
        }
        .frame(width: 80)
    }
}

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
            
            VStack(alignment: .leading, spacing: 12) {
                // CLEAN HORIZONTAL SCROLL
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        addStoryButton
                        
                        // STORY BUBBLES
                        ForEach(stories) { story in
                            AssetBouncyStoryBubble(
                                story: story,
                                onTap: onStoryTap,
                                ns: ns,
                                activeHeroId: activeHeroId
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.Colors.background)
    }

    // 🔥 CLEAN ADD STORY BUTTON - WHITE DESIGN
    private var addStoryButton: some View {
        Button(action: {
            onAddStory()
            HapticManager.shared.impact(style: .medium)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // CLEAN WHITE BORDER
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // CLEAN WHITE BACKGROUND
                    Circle()
                        .fill(Color.white)
                        .frame(width: 74, height: 74)
                        .overlay {
                            ZStack {
                                // CLEAN WHITE PLUS BUTTON
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                }
                
                Text("Your story")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Add your story")
    }
}

// STORY VIEWER (UNCHANGED - ALREADY CLEAN)
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