//
//  VoiceCloneDubbingViewModel.swift
//  MyChannel
//
//  ViewModel for Voice Clone Dubbing
//

import Foundation

struct DubbedVideo: Identifiable, Codable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let languages: [String]
    let totalViews: Int
    let dubbedAt: Date
}

@MainActor
class VoiceCloneDubbingViewModel: ObservableObject {
    @Published var dubbedVideos: [DubbedVideo] = []
    @Published var availableLanguages: [String] = []
    @Published var totalDubbedVideos: Int = 0
    @Published var activeLanguages: Int = 0
    @Published var internationalViews: String = "0"
    @Published var voiceQuality: Int = 85
    
    func loadDubbingData() async {
        // Load all available languages
        availableLanguages = [
            "Spanish", "French", "German", "Italian", "Portuguese",
            "Russian", "Japanese", "Korean", "Chinese (Mandarin)", "Chinese (Cantonese)",
            "Arabic", "Hindi", "Bengali", "Turkish", "Vietnamese",
            "Polish", "Ukrainian", "Romanian", "Dutch", "Greek",
            "Czech", "Swedish", "Hungarian", "Thai", "Indonesian",
            "Hebrew", "Danish", "Finnish", "Norwegian", "Slovak",
            "Croatian", "Bulgarian", "Serbian", "Lithuanian", "Slovenian",
            "Latvian", "Estonian", "Icelandic", "Irish", "Welsh",
            "Swahili", "Zulu", "Afrikaans", "Hausa", "Yoruba",
            "Tagalog", "Malay", "Javanese", "Urdu", "Persian",
            "Pashto", "Kurdish", "Azerbaijani", "Uzbek", "Kazakh",
            "Tamil", "Telugu", "Kannada", "Malayalam", "Marathi",
            "Gujarati", "Punjabi", "Nepali", "Sinhala", "Burmese",
            "Khmer", "Lao", "Mongolian", "Georgian", "Armenian",
            "Amharic", "Somali", "Tigrinya", "Oromo", "Malagasy",
            "Kinyarwanda", "Kirundi", "Sesotho", "Setswana", "Xhosa",
            "Albanian", "Macedonian", "Bosnian", "Montenegrin", "Luxembourgish",
            "Maltese", "Basque", "Catalan", "Galician", "Occitan",
            "Corsican", "Sardinian", "Frisian", "Faroese", "Greenlandic",
            "Hawaiian", "Maori", "Samoan", "Tongan", "Fijian",
            "Tahitian", "Chamorro", "Palauan", "Marshallese", "Yapese"
        ].sorted()
        
        // Mock data
        totalDubbedVideos = 24
        activeLanguages = 12
        internationalViews = "2.4M"
        voiceQuality = 85
        
        // Load dubbed videos from Firestore
        dubbedVideos = [
            DubbedVideo(
                id: "1",
                videoId: "v1",
                title: "How to Build a Successful YouTube Channel",
                thumbnailURL: "",
                languages: ["Spanish", "French", "German", "Italian", "Portuguese"],
                totalViews: 458000,
                dubbedAt: Date().addingTimeInterval(-86400 * 7)
            ),
            DubbedVideo(
                id: "2",
                videoId: "v2",
                title: "My Morning Routine for Maximum Productivity",
                thumbnailURL: "",
                languages: ["Japanese", "Korean", "Chinese (Mandarin)"],
                totalViews: 234000,
                dubbedAt: Date().addingTimeInterval(-86400 * 14)
            )
        ]
    }
}

