//
//  VideoChapter.swift
//  MyChannel
//
//  Video Chapters & Timestamps for YouTube Parity
//

import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - Video Chapters

struct VideoChapter: Identifiable, Codable {
    let id: String
    let videoId: String
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval?
    let thumbnailURL: String?
    let description: String?
    let isGenerated: Bool // Auto-generated vs manual
    
    init(videoId: String, title: String, startTime: TimeInterval, endTime: TimeInterval? = nil, description: String? = nil, isGenerated: Bool = false) {
        self.id = UUID().uuidString
        self.videoId = videoId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.thumbnailURL = nil
        self.description = description
        self.isGenerated = isGenerated
    }
    
    var formattedStartTime: String {
        return TimeInterval.formatTimestamp(startTime)
    }
    
    var formattedDuration: String {
        guard let endTime = endTime else { return "Unknown" }
        let duration = endTime - startTime
        return TimeInterval.formatDuration(duration)
    }
}

// MARK: - Chapter Service

@MainActor
class VideoChapterService: ObservableObject {
    static let shared = VideoChapterService()
    
    @Published var chapters: [String: [VideoChapter]] = [:]
    @Published var isGenerating = false
    
    private init() {}
    
    // MARK: - Chapter Management
    
    func saveChapters(_ chapters: [VideoChapter], for videoId: String) async {
        self.chapters[videoId] = chapters.sorted { $0.startTime < $1.startTime }
        
        // Save to Firestore
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            for chapter in chapters {
                let data = try JSONEncoder().encode(chapter)
                let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                try await db.collection("chapters").document(chapter.id).setData(dict)
            }
        } catch {
            print("Error saving chapters: \(error)")
        }
        #endif
    }
    
    func getChapters(for videoId: String) -> [VideoChapter] {
        return chapters[videoId] ?? []
    }
    
    func addChapter(_ chapter: VideoChapter) async {
        if chapters[chapter.videoId] == nil {
            chapters[chapter.videoId] = []
        }
        chapters[chapter.videoId]?.append(chapter)
        chapters[chapter.videoId]?.sort { $0.startTime < $1.startTime }
        
        await saveChapters(chapters[chapter.videoId] ?? [], for: chapter.videoId)
    }
    
    func deleteChapter(_ chapterId: String, from videoId: String) async {
        chapters[videoId]?.removeAll { $0.id == chapterId }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            try await db.collection("chapters").document(chapterId).delete()
        } catch {
            print("Error deleting chapter: \(error)")
        }
        #endif
    }
    
    // MARK: - Auto-Generation
    
    func generateChapters(for videoId: String, videoDuration: TimeInterval) async -> [VideoChapter] {
        isGenerating = true
        defer { isGenerating = false }
        
        // Simulate AI chapter generation
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let generatedChapters = [
            VideoChapter(
                videoId: videoId,
                title: "Introduction",
                startTime: 0,
                endTime: videoDuration * 0.1,
                description: "Video introduction and overview",
                isGenerated: true
            ),
            VideoChapter(
                videoId: videoId,
                title: "Main Content",
                startTime: videoDuration * 0.1,
                endTime: videoDuration * 0.8,
                description: "Primary content section",
                isGenerated: true
            ),
            VideoChapter(
                videoId: videoId,
                title: "Conclusion",
                startTime: videoDuration * 0.8,
                endTime: videoDuration,
                description: "Summary and closing remarks",
                isGenerated: true
            )
        ]
        
        await saveChapters(generatedChapters, for: videoId)
        return generatedChapters
    }
    
    func parseChaptersFromDescription(_ description: String, videoId: String) -> [VideoChapter] {
        var parsedChapters: [VideoChapter] = []
        let lines = description.components(separatedBy: .newlines)
        
        for line in lines {
            // Look for timestamp patterns like "0:00 Introduction" or "1:23 Chapter Title"
            let pattern = #"(\d{1,2}):(\d{2})\s+(.+)"#
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: line.utf16.count)
            
            if let match = regex?.firstMatch(in: line, range: range) {
                let minutesRange = Range(match.range(at: 1), in: line)
                let secondsRange = Range(match.range(at: 2), in: line)
                let titleRange = Range(match.range(at: 3), in: line)
                
                if let minutesRange = minutesRange,
                   let secondsRange = secondsRange,
                   let titleRange = titleRange,
                   let minutes = Int(line[minutesRange]),
                   let seconds = Int(line[secondsRange]) {
                    
                    let startTime = TimeInterval(minutes * 60 + seconds)
                    let title = String(line[titleRange]).trimmingCharacters(in: .whitespaces)
                    
                    let chapter = VideoChapter(
                        videoId: videoId,
                        title: title,
                        startTime: startTime,
                        isGenerated: false
                    )
                    parsedChapters.append(chapter)
                }
            }
        }
        
        return parsedChapters.sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Extensions

extension TimeInterval {
    static func formatTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        let components = timestamp.components(separatedBy: ":")
        
        if components.count == 2 {
            // MM:SS format
            guard let minutes = Int(components[0]),
                  let seconds = Int(components[1]) else { return nil }
            return TimeInterval(minutes * 60 + seconds)
        } else if components.count == 3 {
            // HH:MM:SS format
            guard let hours = Int(components[0]),
                  let minutes = Int(components[1]),
                  let seconds = Int(components[2]) else { return nil }
            return TimeInterval(hours * 3600 + minutes * 60 + seconds)
        }
        
        return nil
    }
}
