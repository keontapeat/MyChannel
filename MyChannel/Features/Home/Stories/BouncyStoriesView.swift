import SwiftUI
import AVKit

struct BouncyStoryBubble: View {
    let story: Story
    let onTap: (Story) -> Void

    @State private var showProfilePic = true
    @State private var player: AVPlayer?
    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(bounceScale)

                ZStack {
                    if showProfilePic {
                        avatarView
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                            .transition(.opacity)
                            .opacity(showProfilePic ? 1 : 0)
                    } else {
                        mediaView
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                            .transition(.opacity)
                            .opacity(showProfilePic ? 0 : 1)
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

            Text(story.creator?.displayName ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 80)
        }
        .frame(width: 80)
    }

    private var avatarView: some View {
        AsyncImage(url: URL(string: story.creator?.profileImageURL ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            case .failure:
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            @unknown default:
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        ZStack {
            LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 2)
                .opacity(0.9)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 37)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
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

struct BouncyStoriesRow: View {
    let stories: [Story]
    let onStoryTap: (Story) -> Void
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
                        BouncyStoryBubble(story: story, onTap: onStoryTap)
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

#Preview("Bouncy Stories Row") {
    BouncyStoriesRow(
        stories: Story.sampleStories,
        onStoryTap: { _ in },
        onAddStory: {}
    )
    .padding(.vertical)
    .background(Color(.systemBackground))
}