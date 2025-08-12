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
    @State private var selectedPreview: [CreateStoryViewModel.MediaItem] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
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
                    if !selectedPreview.isEmpty {
                        Divider().padding(.top, 6)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedPreview, id: \.id) { item in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 58, height: 58)
                                        .overlay(
                                            Image(systemName: item.type == .video ? "video" : "photo")
                                                .foregroundStyle(.secondary)
                                        )
                                }
                            }
                            .padding(.horizontal)
                        }
                        Button(action: commitSelection) {
                            Text("Continue (\(selectedPreview.count))")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(AppTheme.Colors.primary, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, 8)
                    }
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
                Task { await previewItems(newItems) }
            }
        }
    }
    
    private func previewItems(_ items: [PhotosPickerItem]) async {
        var previews: [CreateStoryViewModel.MediaItem] = []
        for item in items.prefix(10) {
            let mediaType: CreateStoryViewModel.MediaItem.MediaType = item.supportedContentTypes.contains(.movie) ? .video : .image
            let mockURL = URL(string: "https://picsum.photos/400/800?random=\(Int.random(in: 1...100))")!
            previews.append(.init(url: mockURL, type: mediaType, duration: mediaType == .video ? Double.random(in: 5...30) : nil))
        }
        await MainActor.run { selectedPreview = previews }
    }

    private func commitSelection() {
        // For now deliver the first item; in a full flow we'd pass an array
        if let first = selectedPreview.first {
            onMediaSelected(first)
        }
        dismiss()
    }
}

#Preview {
    ModernPhotoPicker { mediaItem in
        print("Media selected: \(mediaItem.url)")
    }
}