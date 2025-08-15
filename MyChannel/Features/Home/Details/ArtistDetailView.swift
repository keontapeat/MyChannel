import SwiftUI

struct ArtistDetailView: View {
    let name: String
    let avatarURL: String
    let videos: [Video]
    let totalViews: Int

    @Environment(\.dismiss) private var dismiss

    private func format(_ n: Int) -> String {
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
            .overlay(
                Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(format(totalViews)) total views")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    Button {
                    } label: {
                        Text("Follow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.blue))
                    }
                    .buttonStyle(.plain)

                    Button {
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Capsule().fill(Color(.systemGray6)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }

    private var videoList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Videos")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 8)

            LazyVStack(spacing: 14) {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(video: video)
                    } label: {
                        VideoListRow(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct VideoListRow: View {
    let video: Video

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image.resizable()
                        .scaledToFill()
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

#Preview("ArtistDetailView") {
    let sample = Array(Video.sampleVideos.prefix(10))
    ArtistDetailView(
        name: sample.first?.creator.displayName ?? "Artist",
        avatarURL: sample.first?.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=artist",
        videos: sample,
        totalViews: sample.reduce(0) { $0 + $1.viewCount }
    )
    .preferredColorScheme(.light)
}