import SwiftUI

struct OwnerFeaturedManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = FeaturedStore.shared
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if store.featured.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 42))
                            .foregroundColor(.yellow)
                        Text("No Featured videos yet")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tap Add to pick videos to feature on Home.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }

            Section("Featured Today (Drag to reorder)") {
                ForEach(store.featured) { item in
                    HStack(spacing: 12) {
                        AppAsyncImage(url: URL(string: item.thumb)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color(.systemGray6) }
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                            Text(item.creatorName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.remove(item.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { indices, newOffset in
                    var items = store.featured
                    items.move(fromOffsets: indices, toOffset: newOffset)
                    store.featured = items
                    // internal persist
                    let mirror = Mirror(reflecting: store)
                    if let method = mirror.children.first(where: { $0.label == "persist" }) {
                        _ = method // no-op
                    }
                }
            }
        }
        .environment(\._editMode, .constant(.active))
        .navigationTitle("Manage Featured")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            OwnerFeaturedPickerView { video in
                FeaturedStore.shared.add(video)
            }
        }
    }
}

private struct OwnerFeaturedPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Video) -> Void

    // Simple sources for now – can wire to Firestore later
    private var candidates: [Video] {
        var vids: [Video] = []
        vids.append(contentsOf: SeedCatalogService.shared.seedVideos)
        vids.append(contentsOf: Video.sampleVideos)
        return Array(Set(vids)).prefix(50).map { $0 }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(candidates) { video in
                    Button {
                        onPick(video)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            AppAsyncImage(url: URL(string: video.thumbnailURL)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color(.systemGray6) }
                            .frame(width: 100, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(2)
                                Text(video.creator.displayName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add Featured")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
