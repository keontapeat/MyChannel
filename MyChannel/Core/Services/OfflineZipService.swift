#if canImport(ZIPFoundation)
import ZIPFoundation
#endif
import Foundation

/// Packages offline video downloads into ZIP archives for export and restore.
@MainActor
final class OfflineZipService: ObservableObject {
    static let shared = OfflineZipService()

    @Published var isExporting = false
    @Published var exportProgress: Double = 0

    private let fileManager = FileManager.default
    private var offlineDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineVideos", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Archive

    func archiveDownloads(videoIds: [String]) async throws -> URL {
        isExporting = true
        defer { isExporting = false }

        let archiveName = "MyChannel_Offline_\(Date().timeIntervalSince1970).zip"
        let archiveURL = fileManager.temporaryDirectory.appendingPathComponent(archiveName)

        #if canImport(ZIPFoundation)
        guard let archive = Archive(url: archiveURL, accessMode: .create) else {
            throw OfflineZipError.archiveCreationFailed
        }

        let total = Double(videoIds.count)
        for (index, videoId) in videoIds.enumerated() {
            let videoFile = offlineDirectory.appendingPathComponent("\(videoId).mp4")
            if fileManager.fileExists(atPath: videoFile.path) {
                try archive.addEntry(with: "\(videoId).mp4", relativeTo: offlineDirectory)
            }
            exportProgress = Double(index + 1) / total
        }
        #else
        throw OfflineZipError.unavailable
        #endif

        return archiveURL
    }

    // MARK: - Restore from ZIP

    func restoreFromArchive(at zipURL: URL) async throws -> [String] {
        var restoredIds: [String] = []

        #if canImport(ZIPFoundation)
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw OfflineZipError.invalidArchive
        }

        for entry in archive {
            let destURL = offlineDirectory.appendingPathComponent(entry.path)
            _ = try archive.extract(entry, to: destURL)
            let videoId = URL(fileURLWithPath: entry.path).deletingPathExtension().lastPathComponent
            restoredIds.append(videoId)
        }
        #else
        throw OfflineZipError.unavailable
        #endif

        return restoredIds
    }

    // MARK: - Storage stats

    var offlineSizeBytes: Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: offlineDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.compactMap {
            try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize
        }.reduce(0) { $0 + Int64($1) }
    }

    func deleteOfflineVideo(videoId: String) {
        let url = offlineDirectory.appendingPathComponent("\(videoId).mp4")
        try? fileManager.removeItem(at: url)
    }

    enum OfflineZipError: Error {
        case archiveCreationFailed
        case invalidArchive
        case unavailable
    }
}
