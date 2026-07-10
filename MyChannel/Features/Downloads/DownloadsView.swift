import SwiftUI
import AVKit
import FirebaseAuth

struct DownloadsView: View {
    @Environment(\.dismiss) private var dismiss
    @Injected private var offlineService: OfflineDownloadService
    @StateObject private var mlService = DownloadMLService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingSettings = false
    @State private var showingUpgrade = false

    // YouTube-parity interactions
    @State private var showingSearchBar = false
    @State private var searchText = ""
    @State private var sortOrder: DownloadSortOrder = .recent
    @State private var downloadingRecommendedIds: Set<String> = []
    @State private var showingDeleteAllAlert = false
    @State private var shareItems: [Any]?

    enum DownloadSortOrder: String, CaseIterable, Identifiable {
        case recent = "Recently added"
        case oldest = "Oldest first"
        case title = "Title (A–Z)"
        case size = "Largest first"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .recent: return "clock"
            case .oldest: return "clock.arrow.circlepath"
            case .title: return "textformat"
            case .size: return "internaldrive"
            }
        }
    }

    private var completedDownloads: [OfflineDownload] {
        offlineService.completedDownloads
    }

    private var inProgressDownloads: [OfflineDownload] {
        offlineService.inProgressDownloads
    }

    private var hasAnyDownloads: Bool {
        !completedDownloads.isEmpty || !inProgressDownloads.isEmpty
    }

    private var filteredDownloads: [OfflineDownload] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = query.isEmpty ? completedDownloads : completedDownloads.filter { $0.title.lowercased().contains(query) }
        return sortedDownloads(base)
    }

    private func sortedDownloads(_ items: [OfflineDownload]) -> [OfflineDownload] {
        switch sortOrder {
        case .recent: return items.sorted { $0.downloadedAt > $1.downloadedAt }
        case .oldest: return items.sorted { $0.downloadedAt < $1.downloadedAt }
        case .title:  return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .size:   return items.sorted { $0.fileSize > $1.fileSize }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Plus gating: offline downloads require MyChannel Plus when subscriptions are enabled.
                // See docs/offline-ios-only.md — web has no offline path; iOS is canonical.
                if AppConfig.Features.enableSubscriptions && !subscriptionService.isPlusSubscriber {
                    plusUpgradePrompt
                } else if !hasAnyDownloads {
                    emptyDownloadsState
                } else {
                    downloadsContent
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .principal) {
                    Text("Downloads")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // AirPlay / Cast — real system route picker
                    AirPlayRoutePickerView()
                        .frame(width: 28, height: 28)
                        .accessibilityLabel("Cast or AirPlay")

                    // Search — toggles inline search field
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingSearchBar.toggle()
                            if !showingSearchBar { searchText = "" }
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: showingSearchBar ? "xmark" : "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!hasAnyDownloads)
                    .opacity(hasAnyDownloads ? 1 : 0.4)
                    .accessibilityLabel(showingSearchBar ? "Close search" : "Search downloads")

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Download settings")

                    // More — sort + manage actions
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(DownloadSortOrder.allCases) { order in
                                Label(order.rawValue, systemImage: order.systemImage).tag(order)
                            }
                        }

                        Divider()

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Download settings", systemImage: "gearshape")
                        }

                        if hasAnyDownloads {
                            Button(role: .destructive) {
                                showingDeleteAllAlert = true
                            } label: {
                                Label("Delete all downloads", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("More options")
                }
            }
            .sheet(isPresented: $showingSettings) {
                DownloadSettingsView()
            }
            .sheet(isPresented: $showingUpgrade) {
                MyChannelPlusView()
            }
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } }
            )) {
                if let items = shareItems {
                    NativeShareSheet(items: items)
                }
            }
            .alert("Delete all downloads", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllDownloads()
                }
            } message: {
                Text("Remove all downloaded videos? This frees up \(ByteCountFormatter.string(fromByteCount: offlineService.usedStorage, countStyle: .file)).")
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadContent()
        }
    }

    // MARK: - Load Content

    private func loadContent() async {
        offlineService.updateStorageInfo()
        await mlService.fetchRecommendedDownloads(limit: 10)
    }

    // MARK: - Plus Upgrade Prompt

    private var plusUpgradePrompt: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 60)

                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)

                    Text("Download videos to watch offline")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Get MyChannel Plus to download videos and watch them anywhere, anytime - even without internet.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 20) {
                    plusFeature(icon: "arrow.down.circle.fill", title: "Download unlimited videos")
                    plusFeature(icon: "wifi.slash", title: "Watch without internet")
                    plusFeature(icon: "play.slash.fill", title: "Ad-free viewing")
                    plusFeature(icon: "hd.circle.fill", title: "HD quality downloads")
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                Button {
                    showingUpgrade = true
                } label: {
                    Text("Try Plus Free")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)

                Text("Then $4.99/month. Cancel anytime.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.top, 8)

                Spacer()
            }
        }
    }

    private func plusFeature(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - Empty Downloads State

    private var emptyDownloadsState: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 60)

                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.system(size: 72))
                        .foregroundColor(.gray)

                    Text("Your downloads")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Videos you download will appear here")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }

                if !mlService.recommendedDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recommended downloads")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        ForEach(mlService.recommendedDownloads.prefix(5)) { video in
                            recommendedDownloadRow(video)
                        }
                    }
                }

                Spacer()
            }
        }
        .refreshable { await loadContent() }
    }

    // MARK: - Downloads Content

    private var downloadsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if showingSearchBar {
                    searchBar
                }

                storageHeader

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)

                // In-progress downloads (YouTube shows active downloads at the top)
                if !inProgressDownloads.isEmpty {
                    HStack {
                        Text("Downloading")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(inProgressDownloads.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    ForEach(inProgressDownloads) { download in
                        activeDownloadRow(download)
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                }

                HStack {
                    Text("Your downloads")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(completedDownloads.count) video\(completedDownloads.count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if filteredDownloads.isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    noSearchResults
                } else {
                    ForEach(filteredDownloads) { download in
                        downloadedVideoRow(download)
                    }
                }

                if !mlService.recommendedDownloads.isEmpty && searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recommended downloads")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 8)

                        ForEach(mlService.recommendedDownloads) { video in
                            recommendedDownloadRow(video)
                        }
                    }
                }
            }
        }
        .refreshable { await loadContent() }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(.gray)

            TextField("Search downloads", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var noSearchResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text("No downloads found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("Try a different search")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Storage Header

    private var storageHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .font(.system(size: 20))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(ByteCountFormatter.string(fromByteCount: offlineService.usedStorage, countStyle: .file)) used")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                ProgressView(value: Double(offlineService.usedStorage) / Double(max(offlineService.maxStorageLimit, 1)))
                    .tint(.blue)
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Text("Manage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Active (In-Progress) Download Row

    private func activeDownloadRow(_ download: OfflineDownload) -> some View {
        HStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: download.thumbnailURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 168, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: download.progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(download.progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(download.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(download.status == .queued ? "Waiting…" : "Downloading…")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                Task { await offlineService.cancelDownload(download.id) }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Cancel download of \(download.title)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Downloaded Video Row

    private func downloadedVideoRow(_ download: OfflineDownload) -> some View {
        Button {
            playDownload(download)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: download.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 168, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    Text(formatDuration(download.duration))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(4)
                        .padding(6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(download.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Available offline")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(ByteCountFormatter.string(fromByteCount: download.fileSize, countStyle: .file))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        Text("•")
                            .foregroundColor(.gray)

                        Text(download.quality.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Menu {
                    Button {
                        playDownload(download)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }

                    Button {
                        shareDownload(download)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            try? await offlineService.deleteDownload(download.id)
                        }
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("More options for \(download.title)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(download.title)
        .accessibilityHint("Available offline. Double tap to play.")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Recommended Download Row

    private func recommendedDownloadRow(_ video: RecommendedDownload) -> some View {
        let isDownloading = downloadingRecommendedIds.contains(video.videoId)
        let isAlreadyDownloaded = offlineService.hasDownload(videoId: video.videoId)

        return VStack(spacing: 0) {
            Button {
                openRecommended(video)
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 168, height: 94)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomTrailing) {
                        Text(video.formattedDuration)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(4)
                            .padding(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(video.channelName)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)

                        Text(video.formattedViewCount)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button {
                        downloadRecommended(video)
                    } label: {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 44, height: 44)
                        } else {
                            Image(systemName: isAlreadyDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                .font(.system(size: 24))
                                .foregroundColor(isAlreadyDownloaded ? .green : .white)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .disabled(isDownloading || isAlreadyDownloaded)
                    .accessibilityLabel(isAlreadyDownloaded ? "Downloaded" : "Download \(video.title)")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(video.title), \(video.channelName)")
        }
    }

    // MARK: - Actions

    private func playDownload(_ download: OfflineDownload) {
        HapticManager.shared.impact(style: .light)

        guard let video = offlineService.offlinePlaybackVideo(for: download.videoId) else {
            // File missing — clean up the stale entry
            Task { try? await offlineService.deleteDownload(download.id) }
            return
        }

        // Dismiss first so the global player presents cleanly over the tab hierarchy.
        dismiss()
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run {
                NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
            }
        }
    }

    private func shareDownload(_ download: OfflineDownload) {
        HapticManager.shared.impact(style: .light)
        guard let url = URL(string: "https://mychannel.live/watch?v=\(download.videoId)") else { return }
        shareItems = [download.title, url]
    }

    private func downloadRecommended(_ recommendation: RecommendedDownload) {
        guard !downloadingRecommendedIds.contains(recommendation.videoId) else { return }
        guard !offlineService.hasDownload(videoId: recommendation.videoId) else { return }

        downloadingRecommendedIds.insert(recommendation.videoId)
        HapticManager.shared.impact(style: .light)

        Task {
            defer { downloadingRecommendedIds.remove(recommendation.videoId) }
            do {
                let fullVideo = try await VideoService.shared.fetchVideo(id: recommendation.videoId)
                _ = try await offlineService.downloadVideo(fullVideo)
                HapticManager.shared.notification(type: .success)
            } catch {
                print("Recommended download failed: \(error.localizedDescription)")
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    private func openRecommended(_ recommendation: RecommendedDownload) {
        HapticManager.shared.impact(style: .light)
        dismiss()
        Task {
            let resolved = try? await VideoService.shared.fetchVideo(id: recommendation.videoId)
            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run {
                if let resolved {
                    NotificationCenter.default.post(name: .openVideoFromHistory, object: resolved)
                }
            }
        }
    }

    private func deleteAllDownloads() {
        HapticManager.shared.impact(style: .heavy)
        Task {
            await offlineService.deleteAllDownloads()
        }
    }
}

#Preview {
    DownloadsView()
}
