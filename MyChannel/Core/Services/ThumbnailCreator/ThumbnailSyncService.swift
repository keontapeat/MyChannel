// 🔥 iOS THUMBNAIL SYNC SERVICE - CROSS-PLATFORM SYNC 💣

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

@MainActor
final class ThumbnailSyncService: ObservableObject {
    static let shared = ThumbnailSyncService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncedAt: Date?
    @Published var pendingChanges: Int = 0
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    private init() {
        setupAutoSync()
    }
    
    // MARK: - Sync Status
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    // MARK: - Sync to Cloud
    
    func syncToCloud(
        projectId: String,
        userId: String,
        state: ThumbnailState
    ) async throws {
        syncStatus = .syncing
        
        do {
            let syncRef = db.collection("mobile-sync").document(projectId)
            
            let syncData: [String: Any] = [
                "projectId": projectId,
                "userId": userId,
                "deviceId": getDeviceId(),
                "deviceType": "ios",
                "deviceName": await getDeviceName(),
                "state": try encodeState(state),
                "version": Date().timeIntervalSince1970,
                "isConflict": false,
                "lastSyncedAt": FieldValue.serverTimestamp()
            ]
            
            try await syncRef.setData(syncData, merge: true)
            
            lastSyncedAt = Date()
            syncStatus = .success
            
            print("✅ [iOS] Synced to cloud:", projectId)
        } catch {
            syncStatus = .error(error.localizedDescription)
            print("🚨 [iOS] Sync failed:", error)
            throw error
        }
    }
    
    // MARK: - Listen for Web Updates
    
    func listenForWebUpdates(
        projectId: String,
        onUpdate: @escaping (ThumbnailState) -> Void,
        onConflict: @escaping (SyncConflict) -> Void
    ) {
        let syncRef = db.collection("mobile-sync").document(projectId)
        
        syncRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("🚨 [iOS] Sync listener error:", error)
                return
            }
            
            guard let data = snapshot?.data() else { return }
            
            do {
                let deviceId = data["deviceId"] as? String ?? ""
                
                // Ignore our own updates
                if deviceId == self.getDeviceId() {
                    return
                }
                
                // Check for conflicts
                if let isConflict = data["isConflict"] as? Bool, isConflict {
                    let conflict = try self.parseConflict(data)
                    onConflict(conflict)
                } else {
                    let state = try self.decodeState(data["state"] as? [String: Any] ?? [:])
                    onUpdate(state)
                }
            } catch {
                print("🚨 [iOS] Failed to parse update:", error)
            }
        }
    }
    
    // MARK: - Auto Sync
    
    private func setupAutoSync() {
        // Sync every 30 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processPendingChanges()
            }
        }
    }
    
    private func processPendingChanges() async {
        // Process offline queue
        let queue = OfflineSyncQueue.shared
        await queue.processQueue()
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(
        projectId: String,
        winningVersion: ConflictResolution,
        state: ThumbnailState
    ) async throws {
        let syncRef = db.collection("mobile-sync").document(projectId)
        
        try await syncRef.updateData([
            "state": try encodeState(state),
            "version": Date().timeIntervalSince1970,
            "isConflict": false,
            "lastSyncedAt": FieldValue.serverTimestamp(),
            "resolvedBy": winningVersion.rawValue
        ])
        
        print("✅ [iOS] Conflict resolved:", winningVersion)
    }
    
    enum ConflictResolution: String {
        case ios
        case web
    }
    
    // MARK: - Export to Native
    
    func exportThumbnail(
        image: UIImage,
        filename: String,
        format: ExportFormat = .png
    ) async throws -> URL {
        // Save to Photos or Files app
        let data: Data?
        
        switch format {
        case .png:
            data = image.pngData()
        case .jpg:
            data = image.jpegData(compressionQuality: 0.95)
        case .webp:
            // WebP support (would need external library)
            data = image.jpegData(compressionQuality: 0.95)
        }
        
        guard let imageData = data else {
            throw ThumbnailError.exportFailed
        }
        
        // Save to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).\(format.rawValue)")
        
        try imageData.write(to: fileURL)
        
        // Save to Photos
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        print("✅ [iOS] Exported:", filename)
        return fileURL
    }
    
    enum ExportFormat: String {
        case png
        case jpg
        case webp
    }
    
    // MARK: - Batch Export
    
    func batchExport(
        images: [(image: UIImage, filename: String)],
        format: ExportFormat = .png,
        onProgress: @escaping (Double) -> Void
    ) async throws -> [URL] {
        var urls: [URL] = []
        
        for (index, item) in images.enumerated() {
            let url = try await exportThumbnail(
                image: item.image,
                filename: item.filename,
                format: format
            )
            urls.append(url)
            
            let progress = Double(index + 1) / Double(images.count)
            onProgress(progress)
        }
        
        print("✅ [iOS] Batch export complete:", images.count)
        return urls
    }
    
    // MARK: - Helpers
    
    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "deviceId") {
            return deviceId
        }
        
        let newId = "ios_\(UUID().uuidString)"
        UserDefaults.standard.set(newId, forKey: "deviceId")
        return newId
    }
    
    private func getDeviceName() async -> String {
        return await UIDevice.current.name
    }
    
    private func encodeState(_ state: ThumbnailState) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }
    
    private func decodeState(_ data: [String: Any]) throws -> ThumbnailState {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        return try decoder.decode(ThumbnailState.self, from: jsonData)
    }
    
    private func parseConflict(_ data: [String: Any]) throws -> SyncConflict {
        // Parse conflict data
        return SyncConflict(
            projectId: data["projectId"] as? String ?? "",
            iosVersion: try decodeState(data["state"] as? [String: Any] ?? [:]),
            webVersion: try decodeState(data["state"] as? [String: Any] ?? [:]),
            conflictedAt: Date()
        )
    }
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Models

struct ThumbnailState: Codable {
    var backgroundImage: String?
    var textLayers: [TextLayer]
    var imageLayers: [ImageLayer]
    var filter: FilterState
}

struct TextLayer: Codable {
    var id: String
    var text: String
    var x: Double
    var y: Double
    var fontSize: Double
    var fontWeight: String
    var fontStyle: String
    var fontFamily: String
    var color: String
    var strokeColor: String
    var strokeWidth: Double
    var align: String
    var rotation: Double
    var opacity: Double
}

struct ImageLayer: Codable {
    var id: String
    var src: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double
    var opacity: Double
}

struct FilterState: Codable {
    var brightness: Double
    var contrast: Double
    var saturation: Double
    var blur: Double
}

struct SyncConflict {
    let projectId: String
    let iosVersion: ThumbnailState
    let webVersion: ThumbnailState
    let conflictedAt: Date
}

enum ThumbnailError: Error {
    case exportFailed
    case syncFailed
    case invalidData
}

// MARK: - Offline Queue

@MainActor
final class OfflineSyncQueue: ObservableObject {
    static let shared = OfflineSyncQueue()
    
    @Published var queuedChanges: [QueuedChange] = []
    
    private let storageKey = "offline_sync_queue"
    
    private init() {
        loadQueue()
    }
    
    struct QueuedChange: Codable {
        let projectId: String
        let state: ThumbnailState
        let timestamp: Date
    }
    
    func addToQueue(projectId: String, state: ThumbnailState) {
        let change = QueuedChange(
            projectId: projectId,
            state: state,
            timestamp: Date()
        )
        
        queuedChanges.append(change)
        saveQueue()
    }
    
    func processQueue() async {
        guard !queuedChanges.isEmpty else { return }
        
        print("📤 [iOS] Processing \(queuedChanges.count) offline syncs...")
        
        var processed: [QueuedChange] = []
        
        for change in queuedChanges {
            do {
                guard let userId = getCurrentUserId() else { continue }
                
                try await ThumbnailSyncService.shared.syncToCloud(
                    projectId: change.projectId,
                    userId: userId,
                    state: change.state
                )
                
                processed.append(change)
                print("✅ [iOS] Offline sync processed:", change.projectId)
            } catch {
                print("🚨 [iOS] Failed to process offline sync:", error)
            }
        }
        
        // Remove processed items
        queuedChanges.removeAll { change in
            processed.contains { $0.projectId == change.projectId }
        }
        
        saveQueue()
    }
    
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            queuedChanges = try JSONDecoder().decode([QueuedChange].self, from: data)
        } catch {
            print("🚨 [iOS] Failed to load offline queue:", error)
        }
    }
    
    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(queuedChanges)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("🚨 [iOS] Failed to save offline queue:", error)
        }
    }
    
    private func getCurrentUserId() -> String? {
        // Get from AuthenticationManager
        return AuthenticationManager.shared.currentUser?.id
    }
}






