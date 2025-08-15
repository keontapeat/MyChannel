import SwiftUI

struct ChannelDetailView: View {
    let name: String
    let avatarURL: String
    let subscribers: Int
    let totalViews: Int
    let videos: [Video]

    @Environment(\.dismiss) private var dismiss
    @State private var isSubscribed: Bool = false

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    videoList
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AppAsyncImage(url: URL(string: avatarURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(fmt(subscribers)) subscribers • \(fmt(totalViews)) views")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        isSubscribed.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSubscribed ? "checkmark" : "plus")
                        Text(isSubscribed ? "Subscribed" : "Subscribe")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSubscribed ? .primary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(isSubscribed ? Color(.systemGray6) : .red))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var videoList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uploads")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 8)

            LazyVStack(spacing: 14) {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(video: video)
                    } label: {
                        VideoRow(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct VideoRow: View {
    let video: Video

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: {
                    Color(.systemGray6)
                }
            )
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(video.creator.displayName, systemImage: "person.crop.circle")
                    Label("\(video.formattedViewCount)", systemImage: "eye")
                    Label(video.formattedDuration, systemImage: "clock")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview("ChannelDetailView") {
    let vids = Array(Video.sampleVideos.prefix(12))
    ChannelDetailView(
        name: vids.first?.creator.displayName ?? "Creator",
        avatarURL: vids.first?.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=creator",
        subscribers: vids.first?.creator.subscriberCount ?? 128_000,
        totalViews: vids.reduce(0) { $0 + $1.viewCount },
        videos: vids
    )
    .preferredColorScheme(.light)
}