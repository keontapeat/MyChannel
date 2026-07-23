import SwiftUI

// MARK: - End Screen Models

/// Represents one end screen element (video/playlist/subscribe/channel/link).
struct EndScreenElement: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var type: EndScreenElementType
    var title: String = ""
    var targetId: String = ""      // videoId, playlistId, channelId, or URL
    var xPct: Double = 0.5        // 0–1 normalised position
    var yPct: Double = 0.5
    var startSeconds: Double = 0   // when the element appears (last 20s of video)
    var endSeconds: Double = 0     // end of video
}

enum EndScreenElementType: String, CaseIterable, Codable, Identifiable {
    case video       = "video"
    case playlist    = "playlist"
    case subscribe   = "subscribe"
    case channel     = "channel"
    case link        = "link"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .video:     return "Video or Playlist"
        case .playlist:  return "Playlist"
        case .subscribe: return "Subscribe button"
        case .channel:   return "Channel"
        case .link:      return "Link"
        }
    }

    var iconName: String {
        switch self {
        case .video:     return "play.rectangle.fill"
        case .playlist:  return "list.bullet.rectangle"
        case .subscribe: return "person.badge.plus"
        case .channel:   return "person.circle.fill"
        case .link:      return "link"
        }
    }
}

// MARK: - End Screen ViewModel

@MainActor
final class EndScreenViewModel: ObservableObject {
    @Published var elements: [EndScreenElement] = []
    @Published var isSaving = false
    @Published var videoDuration: Double = 0
    @Published var error: String?

    private let videoId: String

    init(videoId: String, videoDuration: Double = 0) {
        self.videoId = videoId
        self.videoDuration = videoDuration
        loadFromFirestore()
    }

    func addElement(_ type: EndScreenElementType) {
        guard elements.count < 4 else { return } // YouTube max: 4 elements
        let startSec = max(videoDuration - 20, 0)
        elements.append(EndScreenElement(
            type: type,
            startSeconds: startSec,
            endSeconds: videoDuration
        ))
        HapticManager.shared.impact(style: .light)
    }

    func remove(_ element: EndScreenElement) {
        elements.removeAll { $0.id == element.id }
        HapticManager.shared.impact(style: .rigid)
    }

    func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await saveToFirestore()
                HapticManager.shared.notification(type: .success)
            } catch {
                self.error = error.localizedDescription
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    // MARK: Persistence

    private func loadFromFirestore() {
        Task {
            #if canImport(FirebaseFirestore)
            import FirebaseFirestore
            let snap = try? await Firestore.firestore()
                .collection("videos").document(videoId)
                .getDocument()
            if let data = snap?.data(),
               let raw = data["endScreenElements"] as? [[String: Any]] {
                let decoded = raw.compactMap { dict -> EndScreenElement? in
                    guard let typeRaw = dict["type"] as? String,
                          let type = EndScreenElementType(rawValue: typeRaw) else { return nil }
                    var el = EndScreenElement(type: type)
                    el.id = dict["id"] as? String ?? el.id
                    el.title = dict["title"] as? String ?? ""
                    el.targetId = dict["targetId"] as? String ?? ""
                    el.xPct = dict["xPct"] as? Double ?? 0.5
                    el.yPct = dict["yPct"] as? Double ?? 0.5
                    el.startSeconds = dict["startSeconds"] as? Double ?? 0
                    el.endSeconds = dict["endSeconds"] as? Double ?? videoDuration
                    return el
                }
                await MainActor.run { elements = decoded }
            }
            #endif
        }
    }

    private func saveToFirestore() async throws {
        #if canImport(FirebaseFirestore)
        import FirebaseFirestore
        let payload: [[String: Any]] = elements.map { el in
            [
                "id": el.id,
                "type": el.type.rawValue,
                "title": el.title,
                "targetId": el.targetId,
                "xPct": el.xPct,
                "yPct": el.yPct,
                "startSeconds": el.startSeconds,
                "endSeconds": el.endSeconds
            ]
        }
        try await Firestore.firestore()
            .collection("videos").document(videoId)
            .updateData([
                "endScreenElements": payload,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        #endif
    }
}

// MARK: - End Screen Editor View

struct EndScreenEditorView: View {
    let video: Video
    @StateObject private var viewModel: EndScreenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedElementId: String?

    init(video: Video) {
        self.video = video
        self._viewModel = StateObject(wrappedValue: EndScreenViewModel(
            videoId: video.id,
            videoDuration: video.duration
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewCanvas
                    elementsList
                    addElementSection
                }
                .padding(16)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("End Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.save(); dismiss() }) {
                        if viewModel.isSaving {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    // MARK: Canvas preview

    private var previewCanvas: some View {
        ZStack {
            // Thumbnail behind
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.textTertiary.opacity(0.2))
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // End screen overlay elements
            GeometryReader { geo in
                ForEach(viewModel.elements) { element in
                    EndScreenElementBadge(element: element, isSelected: selectedElementId == element.id)
                        .position(
                            x: element.xPct * geo.size.width,
                            y: element.yPct * geo.size.height
                        )
                        .gesture(DragGesture()
                            .onChanged { drag in
                                guard let idx = viewModel.elements.firstIndex(where: { $0.id == element.id }) else { return }
                                viewModel.elements[idx].xPct = (drag.location.x / geo.size.width).clamped(to: 0...1)
                                viewModel.elements[idx].yPct = (drag.location.y / geo.size.height).clamped(to: 0...1)
                            }
                        )
                        .onTapGesture { selectedElementId = element.id }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("Last 20s")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PlayerChrome.controlBackground, in: Capsule())
                .padding(8)
        }
    }

    // MARK: Elements list

    private var elementsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elements (\(viewModel.elements.count)/4)")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if viewModel.elements.isEmpty {
                Text("Tap + to add an element. You can add up to 4.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                ForEach(viewModel.elements) { element in
                    EndScreenElementRow(
                        element: element,
                        isSelected: selectedElementId == element.id,
                        onSelect: { selectedElementId = element.id },
                        onRemove: { viewModel.remove(element) },
                        onUpdate: { updated in
                            if let idx = viewModel.elements.firstIndex(where: { $0.id == element.id }) {
                                viewModel.elements[idx] = updated
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
    }

    // MARK: Add element section

    private var addElementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add element")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(EndScreenElementType.allCases) { type in
                    Button {
                        viewModel.addElement(type)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.Colors.primary)
                            Text(type.label)
                                .font(AppTheme.Typography.caption2)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md, style: .continuous)
                                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.elements.count >= 4)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg, style: .continuous))
    }
}

// MARK: - Element Badge (canvas overlay)

private struct EndScreenElementBadge: View {
    let element: EndScreenElement
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PlayerChrome.scrimMedium)
                .frame(width: 72, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                )

            VStack(spacing: 2) {
                Image(systemName: element.type.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(element.type.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Element Row (list)

private struct EndScreenElementRow: View {
    let element: EndScreenElement
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onUpdate: (EndScreenElement) -> Void

    @State private var isExpanded = false
    @State private var localTitle: String
    @State private var localTargetId: String

    init(element: EndScreenElement, isSelected: Bool, onSelect: @escaping () -> Void, onRemove: @escaping () -> Void, onUpdate: @escaping (EndScreenElement) -> Void) {
        self.element = element
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onRemove = onRemove
        self.onUpdate = onUpdate
        _localTitle = State(initialValue: element.title)
        _localTargetId = State(initialValue: element.targetId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: element.type.iconName)
                    .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .frame(width: 20)

                Text(localTitle.isEmpty ? element.type.label : localTitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.Colors.error)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            // Expanded editor
            if isExpanded {
                VStack(spacing: 8) {
                    TextField("Label (optional)", text: $localTitle)
                        .font(AppTheme.Typography.caption)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: localTitle) { _ in
                            var updated = element
                            updated.title = localTitle
                            onUpdate(updated)
                        }

                    if element.type != .subscribe {
                        TextField(element.type == .link ? "https://…" : "Video/Playlist/Channel ID", text: $localTargetId)
                            .font(AppTheme.Typography.caption)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: localTargetId) { _ in
                                var updated = element
                                updated.targetId = localTargetId
                                onUpdate(updated)
                            }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(isSelected ? AppTheme.Colors.primary.opacity(0.08) : AppTheme.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm, style: .continuous)
                .stroke(isSelected ? AppTheme.Colors.primary.opacity(0.4) : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview("End Screen Editor") {
    EndScreenEditorView(video: Video.sampleVideos[0])
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
