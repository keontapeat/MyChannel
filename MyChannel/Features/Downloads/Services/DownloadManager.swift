import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadedVideo] = []
    @Published var activeDownloads: [String: Double] = [:]
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private var downloadsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let downloadsDir = documentsDirectory.appendingPathComponent("Downloads")
        
        if !fileManager.fileExists(atPath: downloadsDir.path) {
            try? fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        }
        
        return downloadsDir
    }
    
    private init() {
        loadDownloads()
    }
    
    func checkPlusSubscription() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let isPlusSubscriber = doc.data()?["isPlusSubscriber"] as? Bool ?? false
            return isPlusSubscriber
        } catch {
            print("Error checking Plus subscription: \(error)")
            return false
        }
    }
    
    func downloadVideo(videoId: String, title: String, channelName: String, channelId: String, 
                      thumbnailUrl: String, duration: TimeInterval, viewCount: Int, 
                      videoUrl: String, quality: DownloadedVideo.VideoQuality) async throws {
        
        // 🔥 FIX 2.1(b): Skip subscription check when IAPs not submitted
        if AppConfig.Features.enableSubscriptions {
            let isPlusSubscriber = await checkPlusSubscription()
            guard isPlusSubscriber else {
                throw DownloadError.subscriptionRequired
            }
        }
        
        guard !isVideoDownloaded(videoId: videoId) else {
            throw DownloadError.alreadyDownloaded
        }
        
        guard let url = URL(string: videoUrl) else {
            throw DownloadError.invalidURL
        }
        
        let destinationURL = downloadsDirectory.appendingPathComponent("\(videoId).mp4")
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        
        activeDownloads[videoId] = 0.0
        
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.activeDownloads.removeValue(forKey: videoId)
                    self.error = "Download failed: \(error.localizedDescription)"
                    return
                }
                
                guard let tempURL = tempURL else {
                    self.activeDownloads.removeValue(forKey: videoId)
                    self.error = "Download failed: No file received"
                    return
                }
                
                do {
                    if self.fileManager.fileExists(atPath: destinationURL.path) {
                        try self.fileManager.removeItem(at: destinationURL)
                    }
                    
                    try self.fileManager.moveItem(at: tempURL, to: destinationURL)
                    
                    let attributes = try self.fileManager.attributesOfItem(atPath: destinationURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    let downloadedVideo = DownloadedVideo(
                        videoId: videoId,
                        title: title,
                        channelName: channelName,
                        channelId: channelId,
                        thumbnailUrl: thumbnailUrl,
                        duration: duration,
                        viewCount: viewCount,
                        localFilePath: destinationURL.path,
                        downloadDate: Date(),
                        fileSize: fileSize,
                        quality: quality,
                        isWatched: false
                    )
                    
                    try await self.saveDownloadToFirestore(downloadedVideo)
                    
                    await self.trackDownloadWithML(videoId: videoId, quality: quality.rawValue)
                    
                    self.activeDownloads.removeValue(forKey: videoId)
                    self.loadDownloads()
                    
                } catch {
                    self.activeDownloads.removeValue(forKey: videoId)
                    self.error = "Failed to save download: \(error.localizedDescription)"
                }
            }
        }
        
        downloadTasks[videoId] = task
        task.resume()
    }
    
    private func saveDownloadToFirestore(_ download: DownloadedVideo) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw DownloadError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "videoId": download.videoId,
            "title": download.title,
            "channelName": download.channelName,
            "channelId": download.channelId,
            "thumbnailUrl": download.thumbnailUrl,
            "duration": download.duration,
            "viewCount": download.viewCount,
            "localFilePath": download.localFilePath,
            "downloadDate": Timestamp(date: download.downloadDate),
            "fileSize": download.fileSize,
            "quality": download.quality.rawValue,
            "isWatched": download.isWatched
        ]
        
        try await db.collection("users").document(userId)
            .collection("downloads").document(download.videoId).setData(data)
    }
    
    private func trackDownloadWithML(videoId: String, quality: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let mlData: [String: Any] = [
            "userId": userId,
            "videoId": videoId,
            "quality": quality,
            "timestamp": Timestamp(date: Date()),
            "action": "download"
        ]
        
        do {
            try await db.collection("ml_events").document("downloads")
                .collection("events").addDocument(data: mlData)
            
            let mlUrl = URL(string: "https://watch-time-predictor-fkri6ifojq-uc.a.run.app/track-download")!
            var request = URLRequest(url: mlUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: mlData)
            
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("ML tracking error: \(error)")
        }
    }
    
    func loadDownloads() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        db.collection("users").document(userId).collection("downloads")
            .order(by: "downloadDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.downloads = documents.compactMap { doc in
                        try? doc.data(as: DownloadedVideo.self)
                    }.filter { download in
                        self.fileManager.fileExists(atPath: download.localFilePath)
                    }
                }
            }
    }
    
    func deleteDownload(videoId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw DownloadError.notAuthenticated
        }
        
        guard let download = downloads.first(where: { $0.videoId == videoId }) else {
            throw DownloadError.notFound
        }
        
        let fileURL = URL(fileURLWithPath: download.localFilePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try await db.collection("users").document(userId)
            .collection("downloads").document(videoId).delete()
    }
    
    func cancelDownload(videoId: String) {
        downloadTasks[videoId]?.cancel()
        downloadTasks.removeValue(forKey: videoId)
        activeDownloads.removeValue(forKey: videoId)
    }
    
    func isVideoDownloaded(videoId: String) -> Bool {
        downloads.contains { $0.videoId == videoId }
    }
    
    func getTotalStorageUsed() -> Int64 {
        downloads.reduce(0) { $0 + $1.fileSize }
    }
    
    func getFormattedTotalStorage() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: getTotalStorageUsed())
    }
}

enum DownloadError: LocalizedError {
    case subscriptionRequired
    case alreadyDownloaded
    case invalidURL
    case notAuthenticated
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .subscriptionRequired:
            return "MyChannel Plus subscription required to download videos"
        case .alreadyDownloaded:
            return "Video is already downloaded"
        case .invalidURL:
            return "Invalid video URL"
        case .notAuthenticated:
            return "Please sign in to download videos"
        case .notFound:
            return "Download not found"
        }
    }
}
