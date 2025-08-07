//
//  ModernPhotoPicker.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI

struct ModernPhotoPicker: View {
    let onMediaSelected: (CreateStoryViewModel.MediaItem) -> Void
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 1,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            ) {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Choose Photo or Video")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select from your photo library")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            }
            .navigationTitle("Select Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                guard let item = newItems.first else { return }
                processSelectedItem(item)
            }
        }
    }
    
    private func processSelectedItem(_ item: PhotosPickerItem) {
        Task {
            // For this example, we'll create a mock media item
            // In a real app, you would process the PhotosPickerItem properly
            
            let mediaType: CreateStoryViewModel.MediaItem.MediaType = item.supportedContentTypes.contains(.movie) ? .video : .image
            let mockURL = URL(string: "https://picsum.photos/400/800?random=\(Int.random(in: 1...100))")!
            
            let mediaItem = CreateStoryViewModel.MediaItem(
                url: mockURL,
                type: mediaType,
                duration: mediaType == .video ? Double.random(in: 5...30) : nil
            )
            
            await MainActor.run {
                onMediaSelected(mediaItem)
                dismiss()
            }
        }
    }
}

#Preview {
    ModernPhotoPicker { mediaItem in
        print("Media selected: \(mediaItem.url)")
    }
}