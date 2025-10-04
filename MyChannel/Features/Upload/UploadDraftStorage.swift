//
//  UploadDraftStorage.swift
//  MyChannel
//
//  Created by AI Assistant on 8/13/25.
//

import Foundation
import SwiftUI

struct UploadDraft: Codable, Identifiable {
    let id: String
    let createdAt: Date
    var title: String
    var description: String
    var tags: [String]
    var category: VideoCategory
    var isPublic: Bool
    var monetizationEnabled: Bool
    var localVideoPath: String
    
    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        title: String,
        description: String,
        tags: [String],
        category: VideoCategory,
        isPublic: Bool,
        monetizationEnabled: Bool,
        localVideoPath: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.description = description
        self.tags = tags
        self.category = category
        self.isPublic = isPublic
        self.monetizationEnabled = monetizationEnabled
        self.localVideoPath = localVideoPath
    }
}

@MainActor
final class UploadDraftStorage: ObservableObject {
    static let shared = UploadDraftStorage()
    private let key = "upload_drafts_v1"
    
    @Published private(set) var drafts: [UploadDraft] = []
    
    private init() {
        load()
    }
    
    func saveDraft(from manager: VideoUploadManager) throws -> UploadDraft {
        guard let url = manager.videoURL else { throw UploadError.noVideoSelected }
        let draftsDir = try ensureDraftsDirectory()
        let dst = draftsDir.appendingPathComponent("draft-\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: dst.path) {
            try? FileManager.default.removeItem(at: dst)
        }
        try FileManager.default.copyItem(at: url, to: dst)
        let draft = UploadDraft(
            title: manager.title,
            description: manager.description,
            tags: Array(manager.selectedTags),
            category: manager.selectedCategory,
            isPublic: manager.isPublic,
            monetizationEnabled: manager.monetizationEnabled,
            localVideoPath: dst.path
        )
        drafts.insert(draft, at: 0)
        persist()
        return draft
    }
    
    func hydrateManager(_ manager: VideoUploadManager, with draft: UploadDraft) async {
        manager.title = draft.title
        manager.description = draft.description
        manager.selectedTags = Set(draft.tags)
        manager.selectedCategory = draft.category
        manager.isPublic = draft.isPublic
        manager.monetizationEnabled = draft.monetizationEnabled
        let url = URL(fileURLWithPath: draft.localVideoPath)
        await manager.prepareVideo(from: url)
    }
    
    func delete(_ draft: UploadDraft) {
        drafts.removeAll { $0.id == draft.id }
        persist()
        try? FileManager.default.removeItem(atPath: draft.localVideoPath)
    }
    
    func latest() -> UploadDraft? {
        drafts.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(drafts)
            UserDefaults.standard.set(data, forKey: key)
        } catch { }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([UploadDraft].self, from: data) else { return }
        drafts = decoded
    }
    
    private func ensureDraftsDirectory() throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("drafts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

#Preview("UploadDraftStorage") {
    VStack(spacing: 12) {
        Text("Drafts Available")
            .font(.headline)
        Text("Count: \(UploadDraftStorage.shared.drafts.count)")
            .font(.subheadline)
    }
    .padding()
}