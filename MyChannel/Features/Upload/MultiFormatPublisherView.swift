//
//  MultiFormatPublisherView.swift
//  MyChannel
//
//  Created by Keonta.
//
//  Publishes a single piece of content to multiple destinations (long-form
//  video, Flicks, community post) using the real Firestore services.
//

import SwiftUI

struct MultiFormatPublisherView: View {
    /// The already-uploaded video to cross-publish.
    let video: Video

    @Environment(\.dismiss) private var dismiss
    @State private var publishToVideo = true
    @State private var publishToFlicks = true
    @State private var publishToCommunity = false
    @State private var isPublishing = false
    @State private var resultMessage: String?

    /// A flick is only eligible when it's a short, portrait-friendly clip.
    private var isFlicksEligible: Bool {
        video.duration <= 180
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Destinations")) {
                    Toggle("Long-form Video", isOn: $publishToVideo)
                    Toggle("Flicks", isOn: $publishToFlicks)
                        .disabled(!isFlicksEligible)
                    Toggle("Community Post", isOn: $publishToCommunity)
                }

                if !isFlicksEligible {
                    Section {
                        Label("Flicks works best for clips under 3 minutes.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Details")) {
                    Text("Selecting multiple formats publishes \"\(video.title)\" to each destination.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let resultMessage {
                    Section {
                        Text(resultMessage)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }

                Section {
                    Button(action: publish) {
                        if isPublishing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Publish Now")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isPublishing || !(publishToVideo || publishToFlicks || publishToCommunity))
                    .listRowBackground(AppTheme.Colors.primary)
                }
            }
            .navigationTitle("Multi-Format Publisher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func publish() {
        guard let user = AuthenticationManager.shared.currentUser ?? AppState.shared.currentUser else {
            resultMessage = "Please sign in to publish."
            return
        }
        isPublishing = true
        resultMessage = nil

        Task {
            var published: [String] = []

            // Flicks / Shorts
            if publishToFlicks && isFlicksEligible {
                do {
                    _ = try await ShortsFirestoreService.shared.saveFlick(
                        id: video.id,
                        title: video.title,
                        description: video.description,
                        videoURL: video.videoURL,
                        thumbnailURL: video.thumbnailURL,
                        duration: video.duration,
                        tags: video.tags,
                        userId: user.id,
                        username: user.username,
                        userDisplayName: user.displayName,
                        userProfileImageURL: user.profileImageURL ?? "",
                        userIsVerified: user.isVerified
                    )
                    published.append("Flicks")
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFlicksFeed"), object: video)
                } catch {
                    print("⚠️ [MultiFormatPublisher] Flicks publish failed: \(error)")
                }
            }

            // Long-form video feed refresh (the video already exists in `videos`)
            if publishToVideo {
                published.append("Video")
                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeFeed"), object: video)
            }

            // Community post
            if publishToCommunity {
                published.append("Community")
                NotificationCenter.default.post(name: NSNotification.Name("CreateCommunityPost"), object: video)
            }

            await MainActor.run {
                isPublishing = false
                HapticManager.shared.successPattern()
                resultMessage = published.isEmpty
                    ? "Nothing was published."
                    : "Published to: \(published.joined(separator: ", "))."
            }
        }
    }
}

#Preview {
    MultiFormatPublisherView(video: Video.sampleVideos[0])
}
