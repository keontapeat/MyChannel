//
//  SearchFilters.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation

// 🔥 YouTube-Parity Search Filters
// Complete filter system matching YouTube's search capabilities
struct SearchFilters: Codable, Equatable {
    var uploadDate: UploadDateFilter?
    var duration: DurationFilter?
    var contentType: ContentType?
    var sortBy: SortOption = .relevance
    var features: Set<FeatureFilter> = []
    var category: VideoCategory?
    var quality: QualityFilter?
    var subtitles: SubtitleFilter?
    var location: String?
    var creativeCommons: Bool = false
    var live: Bool = false
    var purchasable: Bool = false
    var hdr: Bool = false
    var vr180: Bool = false
    var threeSixty: Bool = false
    var hd: Bool = false
    var fourK: Bool = false
    
    // MARK: - Upload Date Filter
    enum UploadDateFilter: String, CaseIterable, Codable {
        case lastHour = "Last hour"
        case today = "Today"
        case thisWeek = "This week"
        case thisMonth = "This month"
        case thisYear = "This year"
        
        var dateRange: DateInterval? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .lastHour:
                return DateInterval(start: calendar.date(byAdding: .hour, value: -1, to: now) ?? now, end: now)
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                return DateInterval(start: startOfDay, end: now)
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                return DateInterval(start: startOfWeek, end: now)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return DateInterval(start: startOfMonth, end: now)
            case .thisYear:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                return DateInterval(start: startOfYear, end: now)
            }
        }
    }
    
    // MARK: - Duration Filter
    enum DurationFilter: String, CaseIterable, Codable {
        case short = "Under 4 minutes"
        case medium = "4-20 minutes"
        case long = "Over 20 minutes"
        
        var durationRange: ClosedRange<TimeInterval>? {
            switch self {
            case .short:
                return 0...240 // 0-4 minutes
            case .medium:
                return 240...1200 // 4-20 minutes
            case .long:
                return 1200...TimeInterval.greatestFiniteMagnitude // 20+ minutes
            }
        }
    }
    
    // MARK: - Content Type Filter
    enum ContentType: String, CaseIterable, Codable {
        case video = "Video"
        case channel = "Channel"
        case playlist = "Playlist"
        case movie = "Movie"
        case show = "Show"
        case live = "Live"
        case premiere = "Premiere"
        
        var searchScope: SearchScope {
            switch self {
            case .video, .movie, .show, .premiere:
                return .videos
            case .channel:
                return .creators
            case .playlist:
                return .playlists
            case .live:
                return .live
            }
        }
    }
    
    // MARK: - Sort Options
    enum SortOption: String, CaseIterable, Codable {
        case relevance = "Relevance"
        case uploadDate = "Upload date"
        case viewCount = "View count"
        case rating = "Rating"
        
        var firestoreField: String {
            switch self {
            case .relevance:
                return "relevanceScore"
            case .uploadDate:
                return "createdAt"
            case .viewCount:
                return "viewCount"
            case .rating:
                return "likeRatio"
            }
        }
        
        var isDescending: Bool {
            switch self {
            case .relevance, .uploadDate, .viewCount, .rating:
                return true
            }
        }
    }
    
    // MARK: - Feature Filters
    enum FeatureFilter: String, CaseIterable, Codable {
        case live = "Live"
        case fourK = "4K"
        case hd = "HD"
        case subtitles = "Subtitles/CC"
        case creativeCommons = "Creative Commons"
        case threeSixty = "360°"
        case vr180 = "VR180"
        case threeD = "3D"
        case hdr = "HDR"
        case location = "Location"
        case purchased = "Purchased"
        
        var icon: String {
            switch self {
            case .live:
                return "dot.radiowaves.left.and.right"
            case .fourK:
                return "4k.tv"
            case .hd:
                return "tv"
            case .subtitles:
                return "captions.bubble"
            case .creativeCommons:
                return "c.circle"
            case .threeSixty:
                return "view.3d"
            case .vr180:
                return "visionpro"
            case .threeD:
                return "cube"
            case .hdr:
                return "sun.max"
            case .location:
                return "location"
            case .purchased:
                return "purchased"
            }
        }
    }
    
    // MARK: - Quality Filter
    enum QualityFilter: String, CaseIterable, Codable {
        case any = "Any"
        case hd = "HD"
        case fourK = "4K"
        case eightK = "8K"
        
        var minimumHeight: Int? {
            switch self {
            case .any:
                return nil
            case .hd:
                return 720
            case .fourK:
                return 2160
            case .eightK:
                return 4320
            }
        }
    }
    
    // MARK: - Subtitle Filter
    enum SubtitleFilter: String, CaseIterable, Codable {
        case any = "Any"
        case withSubtitles = "With subtitles"
        case withoutSubtitles = "Without subtitles"
        case autoGenerated = "Auto-generated"
        case manual = "Manual"
    }
    
    // MARK: - Helper Methods
    
    /// Check if any filters are active
    var hasActiveFilters: Bool {
        return uploadDate != nil ||
               duration != nil ||
               contentType != nil ||
               sortBy != .relevance ||
               !features.isEmpty ||
               category != nil ||
               quality != nil ||
               subtitles != nil ||
               location != nil ||
               creativeCommons ||
               live ||
               purchasable ||
               hdr ||
               vr180 ||
               threeSixty ||
               hd ||
               fourK
    }
    
    /// Get active filter count
    var activeFilterCount: Int {
        var count = 0
        
        if uploadDate != nil { count += 1 }
        if duration != nil { count += 1 }
        if contentType != nil { count += 1 }
        if sortBy != .relevance { count += 1 }
        if !features.isEmpty { count += features.count }
        if category != nil { count += 1 }
        if quality != nil { count += 1 }
        if subtitles != nil { count += 1 }
        if location != nil { count += 1 }
        if creativeCommons { count += 1 }
        if live { count += 1 }
        if purchasable { count += 1 }
        if hdr { count += 1 }
        if vr180 { count += 1 }
        if threeSixty { count += 1 }
        if hd { count += 1 }
        if fourK { count += 1 }
        
        return count
    }
    
    /// Reset all filters to default
    mutating func reset() {
        self = SearchFilters()
    }
    
    /// Apply filters to a Firestore query (for backend integration)
    func applyToQuery(_ query: Any) -> Any {
        // This would be implemented with actual Firestore query building
        // For now, return the query unchanged
        return query
    }
    
    /// Convert to URL parameters for API calls
    var urlParameters: [String: String] {
        var params: [String: String] = [:]
        
        if let uploadDate = uploadDate {
            params["upload_date"] = uploadDate.rawValue
        }
        
        if let duration = duration {
            params["duration"] = duration.rawValue
        }
        
        if let contentType = contentType {
            params["content_type"] = contentType.rawValue
        }
        
        params["sort_by"] = sortBy.rawValue
        
        if !features.isEmpty {
            params["features"] = features.map { $0.rawValue }.joined(separator: ",")
        }
        
        if let category = category {
            params["category"] = category.rawValue
        }
        
        if let quality = quality {
            params["quality"] = quality.rawValue
        }
        
        if let subtitles = subtitles {
            params["subtitles"] = subtitles.rawValue
        }
        
        if let location = location {
            params["location"] = location
        }
        
        if creativeCommons {
            params["creative_commons"] = "true"
        }
        
        if live {
            params["live"] = "true"
        }
        
        if purchasable {
            params["purchasable"] = "true"
        }
        
        if hdr {
            params["hdr"] = "true"
        }
        
        if vr180 {
            params["vr180"] = "true"
        }
        
        if threeSixty {
            params["360"] = "true"
        }
        
        if hd {
            params["hd"] = "true"
        }
        
        if fourK {
            params["4k"] = "true"
        }
        
        return params
    }
}

// MARK: - Video Category Extension
extension VideoCategory {
    var searchFilterDisplayName: String {
        return self.displayName
    }
}

// MARK: - Search Scope Extension  
extension SearchScope {
    var contentType: SearchFilters.ContentType? {
        switch self {
        case .all:
            return nil
        case .videos:
            return .video
        case .creators:
            return .channel
        case .playlists:
            return .playlist
        case .live:
            return .live
        case .community:
            return nil // Community posts don't have a direct content type
        }
    }
}
