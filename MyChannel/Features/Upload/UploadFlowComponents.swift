// ⚡ PERFORMANCE: Extracted from YouTubeStyleUploadFlow.swift — independent compilation unit.
// Visibility cards, tab indicator, tag chips, RecentVideo model + cell compile in parallel.
import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Supporting Types and Views

enum CreateContentMode: String, CaseIterable, Hashable {
    case video, flicks, live, post
    var title: String {
        switch self {
        case .video:  return "Video"
        case .flicks: return "Flicks"
        case .live:   return "Live"
        case .post:   return "Post"
        }
    }
}

enum UploadStep: Int, CaseIterable {
    case contentSelection = 0
    case videoPreview = 1
    case videoDetails = 2
    case thumbnailSelection = 3
    case publishing = 4
    case completed = 5
    
    var title: String {
        switch self {
        case .contentSelection: return "Create"
        case .videoPreview: return "Edit Your Video"
        case .videoDetails: return "Video Details"
        case .thumbnailSelection: return "Choose Thumbnail"
        case .publishing: return "Publishing"
        case .completed: return "Success!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .contentSelection: return ""
        case .videoPreview: return "Preview and adjust your video"
        case .videoDetails: return "Add title, description, and settings"
        case .thumbnailSelection: return "Pick the perfect thumbnail"
        case .publishing: return "Your video is being processed"
        case .completed: return ""
        }
    }
    
    var canSkip: Bool {
        switch self {
        case .videoDetails, .thumbnailSelection: return true
        default: return false
        }
    }
    
    var nextButtonTitle: String {
        switch self {
        case .videoPreview: return "Continue"
        case .videoDetails: return "Next"
        case .thumbnailSelection: return "Publish"
        default: return "Next"
        }
    }
}

struct VisibilityOptionCard: View {
    let visibility: VideoVisibility
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: visibilityIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(visibilityTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(visibilityDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red.opacity(0.05) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var visibilityIcon: String {
        switch visibility {
        case .publicVideo: return "globe"
        case .unlisted: return "link"
        case .privateVideo: return "lock"
        }
    }
    
    private var visibilityTitle: String {
        switch visibility {
        case .publicVideo: return "Public"
        case .unlisted: return "Unlisted"
        case .privateVideo: return "Private"
        }
    }
    
    private var visibilityDescription: String {
        switch visibility {
        case .publicVideo: return "Anyone can search for and view"
        case .unlisted: return "Anyone with the link can view"
        case .privateVideo: return "Only you can view"
        }
    }
}

struct TabIndicator: View {
    let icon: String
    let title: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .red : .gray)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .red : .gray)
        }
    }
}

struct UploadFlowTagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }
}

// MARK: - Recent Video Model

struct RecentVideo: Identifiable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage?
    let duration: TimeInterval
    let creationDate: Date
    
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: creationDate, relativeTo: Date())
    }
}

// MARK: - Recent Video Cell

struct RecentVideoCell: View {
    let video: RecentVideo
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Thumbnail
            if let thumbnail = video.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(9/16, contentMode: .fill)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
            
            // Duration badge
            Text(video.formattedDuration)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(6)
        }
        .contentShape(Rectangle())
    }
}

struct CameraRecorderView: UIViewControllerRepresentable {
    let onVideoRecorded: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 600
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraRecorderView
        
        init(_ parent: CameraRecorderView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.onVideoRecorded(videoURL)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    YouTubeStyleUploadFlow()
        .environmentObject(AppState())
}
