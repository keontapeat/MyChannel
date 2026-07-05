import SwiftUI

struct VideoInfoSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info Section
                    InfoSection(title: "Basic Information") {
                        InfoRow(label: "Video ID", value: video.id)
                        InfoRow(label: "Duration", value: formatDuration(video.duration))
                        InfoRow(label: "Upload Date", value: formatDate(video.createdAt))
                        InfoRow(label: "Category", value: video.category.rawValue.capitalized)
                        InfoRow(label: "Language", value: languageText)
                    }
                    
                    // Statistics Section
                    InfoSection(title: "Statistics") {
                        InfoRow(label: "Views", value: "\(video.viewCount.formatted())")
                        InfoRow(label: "Likes", value: "\(video.likeCount.formatted())")
                        InfoRow(label: "Dislikes", value: "\(video.dislikeCount.formatted())")
                        InfoRow(label: "Comments", value: "\(video.commentCount.formatted())")
                        InfoRow(label: "Engagement Rate", value: calculateEngagementRate())
                    }
                    
                    // Technical Details Section
                    InfoSection(title: "Technical Details") {
                        InfoRow(label: "Resolution", value: resolutionText)
                        InfoRow(label: "Available Quality", value: availableQualityText)
                        InfoRow(label: "Streaming", value: video.videoURL.contains(".m3u8") ? "HLS (adaptive)" : "Progressive")
                        InfoRow(label: "Subtitles", value: subtitlesText)
                        InfoRow(label: "File Size", value: "~\(estimateFileSize()) MB")
                    }
                    
                    // Content Details Section
                    InfoSection(title: "Content Details") {
                        if !video.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(video.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if let chapters = video.chapters, !chapters.isEmpty {
                            InfoRow(label: "Chapters", value: "\(chapters.count) chapters")
                        }
                        
                        InfoRow(label: "Age Restriction", value: video.ageRestricted == true ? "Yes" : "No")
                        InfoRow(label: "Made for Kids", value: video.madeForKids == true ? "Yes" : "No")
                    }
                    
                    // Creator Information Section
                    InfoSection(title: "Creator Information") {
                        InfoRow(label: "Channel", value: video.creator.displayName)
                        InfoRow(label: "Subscribers", value: "\(video.creator.subscriberCount.formatted())")
                        InfoRow(label: "Verified", value: video.creator.isVerified ? "Yes" : "No")
                        InfoRow(label: "Joined", value: formatDate(video.creator.joinDate))
                    }
                    
                    // Licensing Section
                    InfoSection(title: "Licensing") {
                        InfoRow(label: "License", value: "Standard YouTube License")
                        InfoRow(label: "Rights Management", value: "Enabled")
                        InfoRow(label: "Content ID", value: "Monitored")
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Video Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Copy Info") {
                        copyVideoInfo()
                    }
                }
            }
        }
        .background(
            UIKitSheetConfigurator(
                configuration: UIKitSheetConfiguration(
                    detents: [.medium(), .large()],
                    largestUndimmedDetentIdentifier: .large,
                    prefersGrabberVisible: true,
                    prefersScrollingExpandsWhenScrolledToEdge: false,
                    preferredCornerRadius: 28
                )
            )
        )
    }
    
    // MARK: - Real technical metadata (from the Video model, not hardcoded)

    /// Highest concrete quality the video offers (ignores `.auto`).
    private var bestQuality: VideoQuality? {
        video.quality.filter { $0 != .auto }.max { $0.sortOrder < $1.sortOrder }
    }

    private var resolutionText: String {
        guard let q = bestQuality else { return "Adaptive" }
        let r = q.resolution
        return "\(Int(r.width))×\(Int(r.height))"
    }

    private var availableQualityText: String {
        let qualities = video.quality.filter { $0 != .auto }.sorted { $0.sortOrder < $1.sortOrder }
        return qualities.isEmpty ? "Adaptive" : qualities.map { $0.displayName }.joined(separator: ", ")
    }

    private var languageText: String {
        if let lang = video.language, !lang.isEmpty { return lang.capitalized }
        if let firstSub = video.subtitles?.first?.language, !firstSub.isEmpty { return firstSub }
        return "Not specified"
    }

    private var subtitlesText: String {
        guard let subs = video.subtitles, !subs.isEmpty else { return "None" }
        return subs.map { $0.language }.joined(separator: ", ")
    }

    private func calculateEngagementRate() -> String {
        let totalEngagements = video.likeCount + video.dislikeCount + video.commentCount
        let rate = video.viewCount > 0 ? (Double(totalEngagements) / Double(video.viewCount)) * 100 : 0
        return String(format: "%.2f%%", rate)
    }
    
    private func estimateFileSize() -> Int {
        // Rough estimation based on duration (assuming 1080p)
        let mbPerMinute = 50 // Approximate MB per minute for 1080p
        return Int(video.duration / 60) * mbPerMinute
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyVideoInfo() {
        let info = """
        Video: \(video.title)
        Creator: \(video.creator.displayName)
        Duration: \(formatDuration(video.duration))
        Views: \(video.viewCount.formatted())
        Upload Date: \(formatDate(video.createdAt))
        Category: \(video.category.rawValue.capitalized)
        """
        
        UIPasteboard.general.string = info
        
        // Show feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// FlowLayout is now in Core/Components/FlowLayout.swift (shared component)

#Preview {
    VideoInfoSheet(video: Video.sampleVideos[0])
}
