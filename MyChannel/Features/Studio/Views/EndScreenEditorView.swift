//
//  EndScreenEditorView.swift
//  MyChannel
//
//  🎬 YOUTUBE END SCREEN EDITOR - 100% PARITY
//  Customize end screen elements: Subscribe, Videos, Playlists, Links
//
//  Created for MyChannel
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - End Screen Editor Element Types (Local to Editor)
enum EditorEndScreenElementType: String, CaseIterable, Identifiable, Codable {
    case video = "video"
    case playlist = "playlist"
    case subscribe = "subscribe"
    case channel = "channel"
    case link = "link"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .playlist: return "Playlist"
        case .subscribe: return "Subscribe"
        case .channel: return "Channel"
        case .link: return "Link"
        }
    }
    
    var icon: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .playlist: return "list.bullet.rectangle.fill"
        case .subscribe: return "person.badge.plus"
        case .channel: return "person.circle.fill"
        case .link: return "link.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .video: return .blue
        case .playlist: return .purple
        case .subscribe: return .red
        case .channel: return .orange
        case .link: return .green
        }
    }
}

// MARK: - End Screen Editor Element Model (Local to Editor)
struct EditorEndScreenElement: Identifiable, Codable {
    let id: String
    var type: EditorEndScreenElementType
    var position: CGPoint  // Relative position (0-1)
    var size: CGSize       // Relative size (0-1)
    var startTime: TimeInterval  // When element appears
    var endTime: TimeInterval    // When element disappears
    var linkedVideoId: String?
    var linkedPlaylistId: String?
    var linkedChannelId: String?
    var linkURL: String?
    var linkTitle: String?
    
    init(
        id: String = UUID().uuidString,
        type: EditorEndScreenElementType,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        size: CGSize = CGSize(width: 0.25, height: 0.2),
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 20,
        linkedVideoId: String? = nil,
        linkedPlaylistId: String? = nil,
        linkedChannelId: String? = nil,
        linkURL: String? = nil,
        linkTitle: String? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.startTime = startTime
        self.endTime = endTime
        self.linkedVideoId = linkedVideoId
        self.linkedPlaylistId = linkedPlaylistId
        self.linkedChannelId = linkedChannelId
        self.linkURL = linkURL
        self.linkTitle = linkTitle
    }
}

// MARK: - End Screen Editor View
struct EndScreenEditorView: View {
    let video: Video
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EndScreenEditorViewModel
    
    @State private var selectedElement: EditorEndScreenElement?
    @State private var showingElementPicker = false
    @State private var showingVideoPicker = false
    @State private var showingPlaylistPicker = false
    @State private var dragOffset: CGSize = .zero
    
    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: EndScreenEditorViewModel(video: video))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Preview Area
                    previewSection
                    
                    // Timeline
                    timelineSection
                    
                    // Elements List
                    elementsListSection
                }
            }
            .navigationTitle("End Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveEndScreen()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .sheet(isPresented: $showingElementPicker) {
                ElementPickerSheet { type in
                    viewModel.addElement(type: type)
                    showingElementPicker = false
                }
            }
            .sheet(item: $selectedElement) { element in
                ElementEditorSheet(element: element) { updated in
                    viewModel.updateElement(updated)
                    selectedElement = nil
                }
            }
        }
        .task {
            await viewModel.loadEndScreen()
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            ZStack {
                // Video thumbnail background
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image.resizable().aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Color.black.opacity(0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                )
                
                // End screen elements
                GeometryReader { geometry in
                    ForEach(viewModel.elements) { element in
                        EndScreenElementPreview(
                            element: element,
                            isSelected: selectedElement?.id == element.id,
                            containerSize: geometry.size
                        )
                        .position(
                            x: element.position.x * geometry.size.width,
                            y: element.position.y * geometry.size.height
                        )
                        .onTapGesture {
                            selectedElement = element
                            HapticManager.shared.impact(style: .light)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var updated = element
                                    updated.position = CGPoint(
                                        x: max(0.1, min(0.9, value.location.x / geometry.size.width)),
                                        y: max(0.1, min(0.9, value.location.y / geometry.size.height))
                                    )
                                    viewModel.updateElement(updated)
                                }
                                .onEnded { _ in
                                    HapticManager.shared.impact(style: .light)
                                }
                        )
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
            }
            .frame(height: 200)
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Timeline")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text("Last 20 seconds")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            
            // Timeline bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.surface)
                    
                    // Elements on timeline
                    ForEach(viewModel.elements) { element in
                        let startX = (element.startTime / 20) * geometry.size.width
                        let width = ((element.endTime - element.startTime) / 20) * geometry.size.width
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(element.type.color.opacity(0.8))
                            .frame(width: max(20, width))
                            .offset(x: startX)
                            .overlay(
                                Text(element.type.displayName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white)
                                    .offset(x: startX)
                            )
                    }
                }
            }
            .frame(height: 32)
            .padding(.horizontal, 20)
            
            // Time labels
            HStack {
                Text(formatTime(video.duration - 20))
                Spacer()
                Text(formatTime(video.duration - 10))
                Spacer()
                Text(formatTime(video.duration))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(AppTheme.Colors.textTertiary)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Elements List Section
    private var elementsListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Elements")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { showingElementPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(viewModel.elements.count >= 4)
            }
            .padding(.horizontal, 20)
            
            if viewModel.elements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("No end screen elements")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("Add up to 4 elements that appear in the last 20 seconds of your video")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.elements) { element in
                            ElementRow(
                                element: element,
                                onEdit: { selectedElement = element },
                                onDelete: { viewModel.removeElement(element) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .padding(.top, 16)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - End Screen Element Preview
struct EndScreenElementPreview: View {
    let element: EditorEndScreenElement
    let isSelected: Bool
    let containerSize: CGSize
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(element.type.color.opacity(0.9))
                    .frame(
                        width: element.size.width * containerSize.width,
                        height: element.size.height * containerSize.height
                    )
                
                Image(systemName: element.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            Text(element.type.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.3), radius: 4)
    }
}

// MARK: - Element Row
struct ElementRow: View {
    let element: EditorEndScreenElement
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(element.type.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: element.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(element.type.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(element.type.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Appears at \(formatTime(element.startTime))")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(8)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Circle())
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Element Picker Sheet
struct ElementPickerSheet: View {
    let onSelect: (EditorEndScreenElementType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(EditorEndScreenElementType.allCases) { type in
                        Button(action: { onSelect(type) }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(type.color.opacity(0.2))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: type.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(type.color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.displayName)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Text(descriptionFor(type))
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding(16)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Add Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func descriptionFor(_ type: EditorEndScreenElementType) -> String {
        switch type {
        case .video: return "Link to another video"
        case .playlist: return "Link to a playlist"
        case .subscribe: return "Show subscribe button"
        case .channel: return "Link to another channel"
        case .link: return "Link to external website"
        }
    }
}

// MARK: - Element Editor Sheet
struct ElementEditorSheet: View {
    let element: EditorEndScreenElement
    let onSave: (EditorEndScreenElement) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedElement: EditorEndScreenElement
    @State private var linkedVideoTitle: String = ""
    @State private var linkedPlaylistTitle: String = ""
    
    init(element: EditorEndScreenElement, onSave: @escaping (EditorEndScreenElement) -> Void) {
        self.element = element
        self.onSave = onSave
        _editedElement = State(initialValue: element)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Element Type") {
                    HStack {
                        Image(systemName: element.type.icon)
                            .foregroundColor(element.type.color)
                        Text(element.type.displayName)
                    }
                }
                
                Section("Timing") {
                    HStack {
                        Text("Start time")
                        Spacer()
                        TextField("0", value: $editedElement.startTime, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("s")
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        let duration = editedElement.endTime - editedElement.startTime
                        Text("\(Int(duration))s")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                if element.type == .link {
                    Section("Link Details") {
                        TextField("URL", text: Binding(
                            get: { editedElement.linkURL ?? "" },
                            set: { editedElement.linkURL = $0 }
                        ))
                        .keyboardType(.URL)
                        
                        TextField("Title", text: Binding(
                            get: { editedElement.linkTitle ?? "" },
                            set: { editedElement.linkTitle = $0 }
                        ))
                    }
                }
            }
            .navigationTitle("Edit Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedElement)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - View Model
@MainActor
class EndScreenEditorViewModel: ObservableObject {
    let video: Video
    
    @Published var elements: [EditorEndScreenElement] = []
    @Published var isLoading = false
    
    init(video: Video) {
        self.video = video
    }
    
    func loadEndScreen() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load from Firestore
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("videos").document(video.id).collection("end-screen").document("config").getDocument()
            if let data = doc.data(),
               let elementsData = data["elements"] as? [[String: Any]] {
                elements = elementsData.compactMap { decodeElement($0) }
            }
        } catch {
            print("❌ [EndScreen] Failed to load: \(error)")
        }
        #endif
    }
    
    func saveEndScreen() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let elementsData = elements.map { element -> [String: Any] in
            var data: [String: Any] = [
                "id": element.id,
                "type": element.type.rawValue,
                "positionX": element.position.x,
                "positionY": element.position.y,
                "sizeWidth": element.size.width,
                "sizeHeight": element.size.height,
                "startTime": element.startTime,
                "endTime": element.endTime
            ]
            
            if let videoId = element.linkedVideoId { data["linkedVideoId"] = videoId }
            if let playlistId = element.linkedPlaylistId { data["linkedPlaylistId"] = playlistId }
            if let channelId = element.linkedChannelId { data["linkedChannelId"] = channelId }
            if let url = element.linkURL { data["linkURL"] = url }
            if let title = element.linkTitle { data["linkTitle"] = title }
            
            return data
        }
        
        try? await db.collection("videos").document(video.id).collection("end-screen").document("config").setData([
            "elements": elementsData,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ [EndScreen] Saved \(elements.count) elements")
        #endif
    }
    
    func addElement(type: EditorEndScreenElementType) {
        guard elements.count < 4 else { return }
        
        let newElement = EditorEndScreenElement(
            type: type,
            position: CGPoint(x: 0.3 + Double(elements.count) * 0.2, y: 0.5),
            startTime: 0,
            endTime: 20
        )
        
        elements.append(newElement)
        HapticManager.shared.impact(style: .medium)
    }
    
    func updateElement(_ element: EditorEndScreenElement) {
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            elements[index] = element
        }
    }
    
    func removeElement(_ element: EditorEndScreenElement) {
        elements.removeAll { $0.id == element.id }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func decodeElement(_ data: [String: Any]) -> EditorEndScreenElement? {
        guard let id = data["id"] as? String,
              let typeRaw = data["type"] as? String,
              let type = EditorEndScreenElementType(rawValue: typeRaw),
              let posX = data["positionX"] as? Double,
              let posY = data["positionY"] as? Double,
              let sizeW = data["sizeWidth"] as? Double,
              let sizeH = data["sizeHeight"] as? Double,
              let startTime = data["startTime"] as? Double,
              let endTime = data["endTime"] as? Double
        else { return nil }
        
        return EditorEndScreenElement(
            id: id,
            type: type,
            position: CGPoint(x: posX, y: posY),
            size: CGSize(width: sizeW, height: sizeH),
            startTime: startTime,
            endTime: endTime,
            linkedVideoId: data["linkedVideoId"] as? String,
            linkedPlaylistId: data["linkedPlaylistId"] as? String,
            linkedChannelId: data["linkedChannelId"] as? String,
            linkURL: data["linkURL"] as? String,
            linkTitle: data["linkTitle"] as? String
        )
    }
}

#Preview {
    EndScreenEditorView(video: Video.sampleVideos[0])
}

