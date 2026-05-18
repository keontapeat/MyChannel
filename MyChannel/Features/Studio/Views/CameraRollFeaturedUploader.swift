//
//  CameraRollFeaturedUploader.swift
//  MyChannel
//

import SwiftUI
import AVFoundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// MARK: - Camera Roll Featured Uploader

@MainActor
class CameraRollFeaturedUploader: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var statusText: String = ""

    func upload(videoURL: URL, title: String, description: String, thumbnail: UIImage?) async -> Video? {
        isUploading = true
        uploadProgress = 0
        errorMessage = nil
        statusText = "Preparing upload..."
        defer { isUploading = false }

        #if canImport(FirebaseStorage) && canImport(FirebaseFirestore)
        do {
            let videoId = UUID().uuidString
            let creatorId = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id ?? ""
            guard !creatorId.isEmpty else {
                errorMessage = "Sign in before uploading a featured video."
                return nil
            }
            let storage = Storage.storage()

            statusText = "Uploading video..."
            let videoRef = storage.reference().child("videos/\(creatorId)/\(videoId)/video.mp4")
            let videoData = try Data(contentsOf: videoURL)
            let videoMeta = StorageMetadata()
            videoMeta.contentType = "video/mp4"
            videoMeta.customMetadata = [
                "userId": creatorId,
                "ownerUid": creatorId,
                "videoId": videoId,
                "source": "featured_camera_roll"
            ]

            _ = try await videoRef.putDataAsync(videoData, metadata: videoMeta) { [weak self] progress in
                guard let self, let progress else { return }
                Task { @MainActor in
                    self.uploadProgress = progress.fractionCompleted * (thumbnail != nil ? 0.8 : 1.0)
                }
            }
            let videoDownloadURL = try await videoRef.downloadURL()

            // Upload thumbnail if available
            var thumbnailURLString = ""
            if let thumbnail, let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
                statusText = "Uploading thumbnail..."
                let thumbRef = storage.reference().child("thumbnails/\(creatorId)/\(videoId)/thumb.jpg")
                let thumbMeta = StorageMetadata()
                thumbMeta.contentType = "image/jpeg"
                thumbMeta.customMetadata = [
                    "userId": creatorId,
                    "ownerUid": creatorId,
                    "videoId": videoId,
                    "source": "featured_camera_roll"
                ]
                _ = try await thumbRef.putDataAsync(jpegData, metadata: thumbMeta)
                let thumbURL = try await thumbRef.downloadURL()
                thumbnailURLString = thumbURL.absoluteString
                uploadProgress = 1.0
            }

            // Get video duration
            statusText = "Reading video details..."
            let asset = AVAsset(url: videoURL)
            let duration = try await asset.load(.duration)
            let durationSecs = CMTimeGetSeconds(duration)

            // Save to Firestore
            statusText = "Saving video..."
            let db = Firestore.firestore()
            let currentUser = AuthenticationManager.shared.currentUser
            let videoDoc: [String: Any] = [
                "id": videoId,
                "title": title,
                "description": description,
                "userId": creatorId,
                "videoURL": videoDownloadURL.absoluteString,
                "videoUrl": videoDownloadURL.absoluteString,
                "thumbnailURL": thumbnailURLString,
                "thumbnailUrl": thumbnailURLString,
                "duration": durationSecs,
                "viewCount": 0,
                "likeCount": 0,
                "commentCount": 0,
                "creatorId": creatorId,
                "ownerUid": creatorId,
                "creatorUsername": currentUser?.username ?? "unknown",
                "creatorDisplayName": currentUser?.displayName ?? "Unknown",
                "creatorName": currentUser?.displayName ?? "Unknown",
                "creatorProfileImage": currentUser?.profileImageURL ?? "",
                "creatorAvatarURL": currentUser?.profileImageURL ?? "",
                "creatorVerified": currentUser?.isVerified ?? false,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "publishedAt": FieldValue.serverTimestamp(),
                "isPublic": true,
                "visibility": "public",
                "status": "published",
                "processingStatus": "completed",
                "category": VideoCategory.other.rawValue,
                "tags": [],
                "source": "camera_roll"
            ]
            try await db.collection("videos").document(videoId).setData(videoDoc)

            let creator = currentUser ?? User(
                id: creatorId,
                username: "unknown",
                displayName: "Unknown",
                email: ""
            )
            let video = Video(
                id: videoId,
                title: title,
                description: description,
                thumbnailURL: thumbnailURLString,
                videoURL: videoDownloadURL.absoluteString,
                duration: durationSecs,
                viewCount: 0,
                likeCount: 0,
                creator: creator,
                category: .other
            )
            statusText = "Uploaded & featured"
            await AnalyticsService.shared.trackEvent("featured_camera_roll_upload_completed", parameters: [
                "videoId": videoId,
                "creatorId": creatorId,
                "duration": durationSecs
            ])
            return video
        } catch {
            errorMessage = friendlyErrorMessage(error)
            statusText = "Upload failed"
            await AnalyticsService.shared.trackEvent("featured_camera_roll_upload_failed", parameters: [
                "error": error.localizedDescription
            ])
            print("❌ [CameraRollFeaturedUploader] Upload failed: \(error)")
            return nil
        }
        #else
        errorMessage = "Firebase not available"
        return nil
        #endif
    }
    
    private func friendlyErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        if lowercased.contains("permission") || lowercased.contains("unauthorized") {
            return "Upload permission denied. Sign in again or check Firebase Storage rules."
        }
        if lowercased.contains("network") || lowercased.contains("offline") || lowercased.contains("timed out") {
            return "Network issue while uploading. Check your connection and try again."
        }
        if lowercased.contains("quota") || lowercased.contains("exceeded") {
            return "Upload limit reached. Try again later."
        }
        return message
    }
}

// MARK: - Camera Roll Upload Sheet

struct CameraRollUploadSheet: View {
    let videoURL: URL
    let thumbnail: UIImage?
    let duration: TimeInterval
    @ObservedObject var uploader: CameraRollFeaturedUploader
    let onComplete: (Video) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Thumbnail preview
                    Group {
                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color(.systemGray5)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 40, weight: .light))
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)

                    // Duration badge
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.black.opacity(0.7))
                            )
                        Spacer()
                    }

                    // Fields
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("Enter a title...", text: $title)
                                .font(.system(size: 16, weight: .regular))
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .focused($titleFocused)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description (optional)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("Add a description...", text: $description, axis: .vertical)
                                .font(.system(size: 15, weight: .regular))
                                .lineLimit(3...6)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Upload progress
                    if uploader.isUploading {
                        VStack(spacing: 10) {
                            ProgressView(value: uploader.uploadProgress)
                                .progressViewStyle(.linear)
                                .tint(AppTheme.Colors.primary)
                            Text("\(uploader.statusText) \(Int(uploader.uploadProgress * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Error
                    if let error = uploader.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Upload button
                    Button {
                        Task {
                            await AnalyticsService.shared.trackEvent("featured_camera_roll_upload_started", parameters: [
                                "duration": duration,
                                "hasThumbnail": thumbnail != nil
                            ])
                            if let video = await uploader.upload(
                                videoURL: videoURL,
                                title: title.isEmpty ? "Untitled Video" : title,
                                description: description,
                                thumbnail: thumbnail
                            ) {
                                NotificationManager.shared.showSuccess("Uploaded & featured")
                                onComplete(video)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if uploader.isUploading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.85)
                                Text("Uploading...")
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Upload & Feature")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(uploader.isUploading || title.isEmpty ? Color(.systemGray3) : Color(.label))
                        )
                    }
                    .disabled(uploader.isUploading || title.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(uploader.isUploading)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(uploader.isUploading)
                }
            }
            .onAppear {
                titleFocused = true
            }
        }
        .background(
            UIKitSheetConfigurator(
                configuration: UIKitSheetConfiguration(
                    detents: [.large()],
                    largestUndimmedDetentIdentifier: .large,
                    prefersGrabberVisible: true,
                    prefersScrollingExpandsWhenScrolledToEdge: false,
                    preferredCornerRadius: 28
                )
            )
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
