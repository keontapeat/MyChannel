// ⚡ PERFORMANCE: Extracted from ContentManagementView.swift — independent compilation unit.
// All nuclear row/grid/sheet components compile in parallel with the 765-line main view.
import SwiftUI

// MARK: - 🔥 NUCLEAR: Bulk Action Button

struct BulkActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 70)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 🔥 NUCLEAR: Video Management Row

struct NuclearVideoManagementRow: View {
    let video: Video
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onViewAnalytics: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection Checkbox
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            }
            
            // Thumbnail with duration overlay
            ZStack(alignment: .bottomTrailing) {
                if let url = URL(string: video.thumbnailURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                }
                
                // Duration badge
                Text(formatDuration(video.duration))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
            .frame(width: 140, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Video Info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                // Stats row
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                        Text(formatNumber(video.viewCount))
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 11))
                        Text(formatNumber(video.likeCount))
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 11))
                        Text(formatNumber(video.commentCount))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(formatDate(video.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Actions Menu
            Menu {
                Button(action: onEdit) {
                    Label("Edit Details", systemImage: "pencil")
                }
                Button(action: onViewAnalytics) {
                    Label("View Analytics", systemImage: "chart.bar")
                }
                Button(action: {}) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Button(action: {}) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                Button(action: {}) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5), in: Circle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? AppTheme.Colors.primary.opacity(0.1) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - 🔥 NUCLEAR: Video Grid Card

struct NuclearVideoGridCard: View {
    let video: Video
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onViewAnalytics: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with selection overlay
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    if let url = URL(string: video.thumbnailURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.systemGray5)
                        }
                    }
                    
                    // Duration
                    Text(formatDuration(video.duration))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 3))
                        .padding(6)
                }
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Selection button
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(isSelected ? AppTheme.Colors.primary : .white.opacity(0.8))
                        .shadow(radius: 4)
                }
                .padding(8)
            }
            
            // Title
            Text(video.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Stats
            HStack(spacing: 8) {
                Label("\(formatNumber(video.viewCount))", systemImage: "eye")
                Label("\(formatNumber(video.likeCount))", systemImage: "hand.thumbsup")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
            
            // Actions
            HStack {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                Button(action: onViewAnalytics) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 12))
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? AppTheme.Colors.primary.opacity(0.1) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - 🔥 NUCLEAR: Video Compact Row

struct NuclearVideoCompactRow: View {
    let video: Video
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            }
            
            Text(video.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            Text("\(video.viewCount) views")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppTheme.Colors.primary.opacity(0.1) : Color(.systemGray6))
        )
    }
}

// MARK: - Stat Card

struct ContentStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?
    
    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Video Editor Sheet

struct VideoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let video: Video
    let onSave: () -> Void
    @State private var title: String
    @State private var description: String
    @State private var category: VideoCategory
    
    init(video: Video, onSave: @escaping () -> Void) {
        self.video = video
        self.onSave = onSave
        _title = State(initialValue: video.title)
        _description = State(initialValue: video.description)
        _category = State(initialValue: video.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Video Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(5...10)
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(VideoCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
                
                Section("Subtitles") {
                    NavigationLink {
                        VideoCaptionsManagerView(videoId: video.id, videoTitle: video.title)
                    } label: {
                        HStack {
                            Image(systemName: "captions.bubble")
                                .foregroundColor(AppTheme.Colors.primary)
                            Text("Manage subtitles & CC")
                        }
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("Edit Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        Task {
            do {
                try await VideoFirestoreService.shared.updateVideoMetadata(
                    videoId: video.id,
                    title: title,
                    description: description,
                    category: category,
                    tags: nil
                )
                HapticManager.shared.notification(type: .success)
                onSave()
                dismiss()
            } catch {
                print("🚨 Error saving video: \(error)")
                HapticManager.shared.notification(type: .error)
            }
        }
    }
}

// MARK: - 🔥 NUCLEAR: Bulk Edit Sheet

struct BulkEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedVideoIds: [String]
    let videos: [Video]
    let onSave: () -> Void
    
    @State private var updateTitle = false
    @State private var newTitle = ""
    @State private var updateDescription = false
    @State private var newDescription = ""
    @State private var updateCategory = false
    @State private var newCategory: VideoCategory = .movies
    @State private var updateTags = false
    @State private var newTags = ""
    @State private var updateMadeForKids = false
    @State private var newMadeForKids = false
    @State private var updateAgeRestricted = false
    @State private var newAgeRestricted = false
    @State private var isApplying = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(selectedVideoIds.count) videos selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Section("Update Fields") {
                    Toggle("Update Title", isOn: $updateTitle)
                    if updateTitle {
                        TextField("New Title", text: $newTitle)
                    }
                    
                    Toggle("Update Description", isOn: $updateDescription)
                    if updateDescription {
                        TextField("New Description", text: $newDescription, axis: .vertical)
                            .lineLimit(3...5)
                    }
                    
                    Toggle("Update Category", isOn: $updateCategory)
                    if updateCategory {
                        Picker("Category", selection: $newCategory) {
                            ForEach(VideoCategory.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }

                    Toggle("Update Tags", isOn: $updateTags)
                    if updateTags {
                        TextField("Comma-separated tags", text: $newTags)
                        Text("Replaces existing tags on selected videos.")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                // 🔥 YouTube parity: audience & restrictions
                Section("Audience & Restrictions") {
                    Toggle("Set 'Made for kids'", isOn: $updateMadeForKids)
                    if updateMadeForKids {
                        Toggle("Made for kids", isOn: $newMadeForKids)
                    }

                    Toggle("Set Age-restriction", isOn: $updateAgeRestricted)
                    if updateAgeRestricted {
                        Toggle("Age-restricted (18+)", isOn: $newAgeRestricted)
                    }
                }
                
                Section {
                    Button {
                        applyBulkEdit()
                    } label: {
                        HStack {
                            if isApplying { ProgressView().tint(.white) }
                            Text(isApplying ? "Applying…" : "Apply to All Selected")
                        }
                    }
                    .disabled(!hasAnyChange || isApplying)
                }
            }
            .navigationTitle("Bulk Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hasAnyChange: Bool {
        updateTitle || updateDescription || updateCategory || updateTags || updateMadeForKids || updateAgeRestricted
    }
    
    private func applyBulkEdit() {
        // Capture @State values on main actor before entering Task
        let title = updateTitle ? newTitle : nil
        let description = updateDescription ? newDescription : nil
        let category = updateCategory ? newCategory : nil
        let tags: [String]? = updateTags
            ? newTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            : nil
        let madeForKids: Bool? = updateMadeForKids ? newMadeForKids : nil
        let ageRestricted: Bool? = updateAgeRestricted ? newAgeRestricted : nil
        isApplying = true
        Task {
            await withTaskGroup(of: Void.self) { group in
                for videoId in selectedVideoIds {
                    group.addTask {
                        do {
                            try await VideoFirestoreService.shared.updateVideoMetadata(
                                videoId: videoId,
                                title: title,
                                description: description,
                                category: category,
                                tags: tags,
                                madeForKids: madeForKids,
                                ageRestricted: ageRestricted
                            )
                        } catch {
                            print("🚨 Error updating video \(videoId): \(error)")
                        }
                    }
                }
            }
            await MainActor.run {
                isApplying = false
                HapticManager.shared.notification(type: .success)
                onSave()
                dismiss()
            }
        }
    }
}

// MARK: - 🔥 NUCLEAR: Bulk Visibility Sheet

struct BulkVisibilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedVideoIds: [String]
    let onSave: () -> Void
    
    @State private var selectedVisibility: VideoVisibility = .public_
    @State private var isApplying = false
    
    enum VideoVisibility: String, CaseIterable {
        case public_ = "Public"
        case unlisted = "Unlisted"
        case private_ = "Private"
        
        var displayName: String {
            self == .private_ || self == .public_ ? rawValue.replacingOccurrences(of: "_", with: "") : rawValue
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(selectedVideoIds.count) videos selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Section("Visibility") {
                    ForEach(VideoVisibility.allCases, id: \.self) { visibility in
                        Button(action: {
                            selectedVisibility = visibility
                        }) {
                            HStack {
                                Text(visibility.displayName)
                                Spacer()
                                if selectedVisibility == visibility {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button("Apply to All Selected") {
                        applyVisibility()
                    }
                    .disabled(isApplying || selectedVideoIds.isEmpty)
                }
            }
            .navigationTitle("Change Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyVisibility() {
        // Capture @State value on main actor before entering Task
        let visibility: Video.VisibilityStatus
        switch selectedVisibility {
        case .public_:
            visibility = .public
        case .unlisted:
            visibility = .unlisted
        case .private_:
            visibility = .private
        }
        Task {
            await MainActor.run { isApplying = true }
            await withTaskGroup(of: Void.self) { group in
                for videoId in selectedVideoIds {
                    group.addTask {
                        do {
                            try await VideoFirestoreService.shared.updateVideoVisibility(videoId: videoId, visibility: visibility)
                        } catch {
                            print("🚨 Failed to update visibility for \(videoId): \(error)")
                        }
                    }
                }
            }
            await MainActor.run {
                isApplying = false
                HapticManager.shared.notification(type: .success)
                onSave()
                dismiss()
            }
        }
    }
}

// MARK: - 🔥 NUCLEAR: Bulk Playlist Sheet

struct BulkPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedVideoIds: [String]
    let onSave: () -> Void
    
    @State private var playlists: [String] = ["Favorites", "Watch Later", "Gaming", "Tutorials"]
    @State private var selectedPlaylists: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(selectedVideoIds.count) videos selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Section("Add to Playlists") {
                    ForEach(playlists, id: \.self) { playlist in
                        Button(action: {
                            if selectedPlaylists.contains(playlist) {
                                selectedPlaylists.remove(playlist)
                            } else {
                                selectedPlaylists.insert(playlist)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedPlaylists.contains(playlist) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedPlaylists.contains(playlist) ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                Text(playlist)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Add to Selected Playlists") {
                        addToPlaylists()
                    }
                    .disabled(selectedPlaylists.isEmpty)
                }
            }
            .navigationTitle("Add to Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addToPlaylists() {
        print("🔥 Add \(selectedVideoIds.count) videos to \(selectedPlaylists.count) playlists")
        // Write to Firestore: each playlist gets the new videoIds appended
        Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                for playlistId in selectedPlaylists {
                    for videoId in selectedVideoIds {
                        group.addTask {
                            try await PlaylistFirestoreService.shared.addVideoToPlaylist(
                                videoId: videoId,
                                playlistId: playlistId
                            )
                        }
                    }
                }
            }
        }
        HapticManager.shared.notification(type: .success)
        onSave()
        dismiss()
    }
}

