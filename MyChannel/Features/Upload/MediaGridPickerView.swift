import SwiftUI
import Photos
import AVFoundation

struct MediaGridPickerView: View {
    enum Mode {
        case video
        case flicks
    }
    
    let mode: Mode
    let title: String
    let onClose: () -> Void
    let onPick: (URL) -> Void
    
    @State private var assets: [PHAsset] = []
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    private let imageManager = PHCachingImageManager()
    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                if authStatus == .authorized || authStatus == .limited {
                    ScrollView {
                        LazyVGrid(columns: gridCols, spacing: 2) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                GridCell(asset: asset, manager: imageManager) {
                                    export(asset: asset)
                                }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                } else if authStatus == .denied || authStatus == .restricted {
                    permissionView
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        
        .task {
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
            await requestAndLoad()
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.95))
    }
    
    private var permissionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.9))
            Text("Allow Photos Access")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text("We need access to show your videos from the gallery.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                    Task { await requestAndLoad() }
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
    }
    
    private func requestAndLoad() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            let status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                    continuation.resume(returning: s)
                }
            }
            await MainActor.run { authStatus = status }
        } else {
            await MainActor.run { authStatus = current }
        }
        guard authStatus == .authorized || authStatus == .limited else { return }
        loadAssets()
    }
    
    private func loadAssets() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetch = PHAsset.fetchAssets(with: .video, options: options)
        
        var list: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            if mode == .flicks {
                if asset.duration <= 60.5 { list.append(asset) }
            } else {
                list.append(asset)
            }
        }
        self.assets = list
        preheatThumbnails(for: list)
    }
    
    private func preheatThumbnails(for assets: [PHAsset]) {
        let target = CGSize(width: 220, height: 220)
        let requests = assets.map { PHAssetResource.assetResources(for: $0); return $0 }
        imageManager.startCachingImages(for: requests, targetSize: target, contentMode: .aspectFill, options: nil)
    }
    
    private func export(asset: PHAsset) {
        let opts = PHVideoRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
            guard let avAsset = avAsset else { return }
            if let urlAsset = avAsset as? AVURLAsset {
                DispatchQueue.main.async {
                    onPick(urlAsset.url)
                }
                return
            }
            let export = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString).mp4")
            export?.outputURL = tempURL
            export?.outputFileType = .mp4
            export?.exportAsynchronously {
                DispatchQueue.main.async {
                    if export?.status == .completed {
                        onPick(tempURL)
                    }
                }
            }
        }
    }
}

private struct GridCell: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    let onTap: () -> Void
    
    @State private var image: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.08)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(formatDuration(asset.duration))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .padding(6)
                }
            }
        }
        .frame(height: UIScreen.main.bounds.width/3 - 1)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .task {
            let size = CGSize(width: 600, height: 600)
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
                if let img { self.image = img }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

#Preview("MediaGridPickerView - Video") {
    MediaGridPickerView(mode: .video, title: "Upload video", onClose: {}, onPick: { _ in })
}