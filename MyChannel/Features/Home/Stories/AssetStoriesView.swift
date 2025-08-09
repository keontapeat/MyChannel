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

struct AssetBouncyStoryBubble: View {
    let story: AssetStory
    let onTap: (AssetStory) -> Void

    @State private var showProfilePic = true
    @State private var bounceScale: CGFloat = 1.0
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(colors: [.purple, .blue, .pink],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(bounceScale)

                ZStack {
                    if showProfilePic {
                        Image(story.authorImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                            .transition(.opacity)
                    } else {
                        mediaView
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: showProfilePic)
                .scaleEffect(bounceScale)
            }
            .contentShape(Circle())
            .onTapGesture { onTap(story) }
            .onAppear {
                startBouncing()
                toggleWithDelay()
            }

            Text(story.username)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 80)
        }
        .frame(width: 80)
    }

    @ViewBuilder
    private var mediaView: some View {
        switch story.media {
        case .image(let name):
            Image(name).resizable().scaledToFill()
        case .video(let resource):
            if let url = Bundle.main.url(forResource: resource, withExtension: nil) {
                VideoPlayer(player: player ?? AVPlayer(url: url))
                    .onAppear {
                        if player == nil { player = AVPlayer(url: url) }
                        player?.play()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { player?.pause() }
                    }
                    .onDisappear { player?.pause() }
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(0.9)
                }
            }
        }
    }

    private func startBouncing() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                bounceScale = bounceScale == 1.0 ? 1.1 : 1.0
            }
        }
    }

    private func toggleWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showProfilePic.toggle()
            }
            toggleWithDelay()
        }
    }
}

struct AssetBouncyStoriesRow: View {
    let stories: [AssetStory]
    let onStoryTap: (AssetStory) -> Void
    let onAddStory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stories")
                    .font(.headline).bold()
                Spacer()
                Button("See all") {}
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    addStoryButton
                    ForEach(stories) { story in
                        AssetBouncyStoryBubble(story: story, onTap: onStoryTap)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var addStoryButton: some View {
        Button(action: onAddStory) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(.separator, lineWidth: 2)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 74, height: 74)
                        .overlay {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.pink, .purple],
                                                         startPoint: .topLeading,
                                                         endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .pink.opacity(0.25), radius: 4, x: 0, y: 2)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                Text("Your story")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add your story")
    }
}

struct AssetStoryViewerView: View {
    let story: AssetStory
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark").foregroundStyle(.white)
                }
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

#Preview("Asset Stories Row") {
    AssetBouncyStoriesRow(
        stories: AssetStory.sampleStories,
        onStoryTap: { _ in },
        onAddStory: {}
    )
    .padding(.vertical)
    .background(Color(.systemBackground))
}

#Preview("Asset Story Bubble") {
    AssetBouncyStoryBubble(
        story: AssetStory.sampleStories.first!,
        onTap: { _ in }
    )
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Asset Story Viewer") {
    NavigationStack {
        AssetStoryViewerView(
            story: AssetStory.sampleStories.first!,
            onDismiss: {}
        )
    }
}