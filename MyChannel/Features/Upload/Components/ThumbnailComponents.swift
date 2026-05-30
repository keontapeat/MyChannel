import SwiftUI
import PhotosUI

struct ThumbnailSelectionView: View {
    let autoThumbnail: UIImage?
    @Binding var customThumbnails: [UIImage]
    @Binding var selectedIndex: Int
    @State private var showingImagePicker = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Auto-generated thumbnail
                if let autoThumbnail = autoThumbnail {
                    ThumbnailOption(
                        image: autoThumbnail,
                        isSelected: selectedIndex == 0,
                        label: "Auto"
                    ) {
                        selectedIndex = 0
                    }
                }
                
                // Custom thumbnails
                ForEach(customThumbnails.indices, id: \.self) { index in
                    ThumbnailOption(
                        image: customThumbnails[index],
                        isSelected: selectedIndex == index + 1,
                        label: nil
                    ) {
                        selectedIndex = index + 1
                    }
                }
                
                // Add custom thumbnail button
                Button {
                    showingImagePicker = true
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.cardBackground)
                            .frame(width: 120, height: 68)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.Colors.divider, style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        
                        Text("Custom")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerWrapper { image in
                if let image = image {
                    customThumbnails.append(image)
                    selectedIndex = customThumbnails.count // Select the newly added thumbnail
                }
            }
        }
    }
}

struct ImagePickerWrapper: UIViewControllerRepresentable {
    let onImageSelected: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerWrapper
        
        init(_ parent: ImagePickerWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            } else {
                parent.onImageSelected(nil)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
            parent.dismiss()
        }
    }
}

struct ThumbnailOption: View {
    let image: UIImage
    let isSelected: Bool
    let label: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider, lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .font(.system(size: 20))
                            }
                        },
                        alignment: .topTrailing
                    )
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

