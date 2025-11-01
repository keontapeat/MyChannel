//
//  MultiLanguageService.swift
//  MyChannel
//
//  Multi-language Metadata Support for YouTube Parity
//

import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - Multi-language Models

struct MultiLanguageMetadata: Identifiable, Codable {
    let id: String
    let videoId: String
    let translations: [String: VideoTranslation] // languageCode: translation
    let primaryLanguage: String
    let autoTranslatedLanguages: Set<String>
    let manuallyTranslatedLanguages: Set<String>
    
    init(videoId: String, primaryLanguage: String = "en") {
        self.id = UUID().uuidString
        self.videoId = videoId
        self.translations = [:]
        self.primaryLanguage = primaryLanguage
        self.autoTranslatedLanguages = []
        self.manuallyTranslatedLanguages = []
    }
    
    init(id: String, videoId: String, translations: [String: VideoTranslation], primaryLanguage: String, autoTranslatedLanguages: Set<String>, manuallyTranslatedLanguages: Set<String>) {
        self.id = id
        self.videoId = videoId
        self.translations = translations
        self.primaryLanguage = primaryLanguage
        self.autoTranslatedLanguages = autoTranslatedLanguages
        self.manuallyTranslatedLanguages = manuallyTranslatedLanguages
    }
}

struct VideoTranslation: Codable {
    let languageCode: String
    let languageName: String
    let title: String
    let description: String
    let tags: [String]
    let isAutoTranslated: Bool
    let translatedAt: Date
    let translatedBy: String? // User ID or "auto"
    
    init(languageCode: String, languageName: String, title: String, description: String, tags: [String] = [], isAutoTranslated: Bool = false, translatedBy: String? = nil) {
        self.languageCode = languageCode
        self.languageName = languageName
        self.title = title
        self.description = description
        self.tags = tags
        self.isAutoTranslated = isAutoTranslated
        self.translatedAt = Date()
        self.translatedBy = translatedBy
    }
}

struct SupportedLanguage: Identifiable, Codable {
    let id: String
    let code: String
    let name: String
    let nativeName: String
    let flag: String
    let isRTL: Bool
    let supportsAutoTranslation: Bool
    
    static let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(id: "en", code: "en", name: "English", nativeName: "English", flag: "🇺🇸", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "es", code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "fr", code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "de", code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "it", code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "pt", code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "ru", code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "ja", code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "ko", code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "zh", code: "zh", name: "Chinese", nativeName: "中文", flag: "🇨🇳", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "hi", code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "ar", code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦", isRTL: true, supportsAutoTranslation: true),
        SupportedLanguage(id: "tr", code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "pl", code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "nl", code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "sv", code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "da", code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "no", code: "no", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "fi", code: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮", isRTL: false, supportsAutoTranslation: true),
        SupportedLanguage(id: "th", code: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭", isRTL: false, supportsAutoTranslation: true)
    ]
}

// MARK: - Multi-language Service

@MainActor
class MultiLanguageService: ObservableObject {
    static let shared = MultiLanguageService()
    
    @Published var videoTranslations: [String: MultiLanguageMetadata] = [:]
    @Published var isTranslating = false
    @Published var translationProgress: Double = 0.0
    
    private init() {}
    
    // MARK: - Translation Management
    
    func getMetadata(for videoId: String) -> MultiLanguageMetadata? {
        return videoTranslations[videoId]
    }
    
    func addTranslation(_ translation: VideoTranslation, to videoId: String) async {
        var metadata = videoTranslations[videoId] ?? MultiLanguageMetadata(videoId: videoId)
        
        var updatedTranslations = metadata.translations
        updatedTranslations[translation.languageCode] = translation
        
        var updatedAutoTranslated = metadata.autoTranslatedLanguages
        var updatedManualTranslated = metadata.manuallyTranslatedLanguages
        
        if translation.isAutoTranslated {
            updatedAutoTranslated.insert(translation.languageCode)
            updatedManualTranslated.remove(translation.languageCode)
        } else {
            updatedManualTranslated.insert(translation.languageCode)
            updatedAutoTranslated.remove(translation.languageCode)
        }
        
        let updatedMetadata = MultiLanguageMetadata(
            id: metadata.id,
            videoId: videoId,
            translations: updatedTranslations,
            primaryLanguage: metadata.primaryLanguage,
            autoTranslatedLanguages: updatedAutoTranslated,
            manuallyTranslatedLanguages: updatedManualTranslated
        )
        
        videoTranslations[videoId] = updatedMetadata
        await saveMetadata(updatedMetadata)
    }
    
    func removeTranslation(languageCode: String, from videoId: String) async {
        guard var metadata = videoTranslations[videoId] else { return }
        
        var updatedTranslations = metadata.translations
        updatedTranslations.removeValue(forKey: languageCode)
        
        var updatedAutoTranslated = metadata.autoTranslatedLanguages
        var updatedManualTranslated = metadata.manuallyTranslatedLanguages
        updatedAutoTranslated.remove(languageCode)
        updatedManualTranslated.remove(languageCode)
        
        let updatedMetadata = MultiLanguageMetadata(
            id: metadata.id,
            videoId: videoId,
            translations: updatedTranslations,
            primaryLanguage: metadata.primaryLanguage,
            autoTranslatedLanguages: updatedAutoTranslated,
            manuallyTranslatedLanguages: updatedManualTranslated
        )
        
        videoTranslations[videoId] = updatedMetadata
        await saveMetadata(updatedMetadata)
    }
    
    // MARK: - Auto Translation
    
    func autoTranslate(videoId: String, originalTitle: String, originalDescription: String, originalTags: [String], to languages: [String]) async {
        isTranslating = true
        translationProgress = 0.0
        
        let totalLanguages = languages.count
        
        for (index, languageCode) in languages.enumerated() {
            guard let language = SupportedLanguage.supportedLanguages.first(where: { $0.code == languageCode }),
                  language.supportsAutoTranslation else {
                continue
            }
            
            // Simulate translation API call
            let translatedContent = await translateContent(
                title: originalTitle,
                description: originalDescription,
                tags: originalTags,
                to: languageCode
            )
            
            let translation = VideoTranslation(
                languageCode: languageCode,
                languageName: language.name,
                title: translatedContent.title,
                description: translatedContent.description,
                tags: translatedContent.tags,
                isAutoTranslated: true,
                translatedBy: "auto"
            )
            
            await addTranslation(translation, to: videoId)
            
            // Update progress
            translationProgress = Double(index + 1) / Double(totalLanguages)
        }
        
        isTranslating = false
        translationProgress = 0.0
    }
    
    private func translateContent(title: String, description: String, tags: [String], to languageCode: String) async -> (title: String, description: String, tags: [String]) {
        // Simulate translation delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // In real implementation, this would call Google Translate API or similar
        // For now, return mock translations
        let mockTranslations: [String: (title: String, description: String)] = [
            "es": ("Título en Español", "Descripción en español del video"),
            "fr": ("Titre en Français", "Description en français de la vidéo"),
            "de": ("Deutscher Titel", "Deutsche Beschreibung des Videos"),
            "it": ("Titolo Italiano", "Descrizione italiana del video"),
            "pt": ("Título em Português", "Descrição em português do vídeo"),
            "ru": ("Русский заголовок", "Русское описание видео"),
            "ja": ("日本語のタイトル", "日本語でのビデオの説明"),
            "ko": ("한국어 제목", "한국어 비디오 설명"),
            "zh": ("中文标题", "中文视频描述"),
            "hi": ("हिंदी शीर्षक", "हिंदी वीडियो विवरण"),
            "ar": ("العنوان العربي", "الوصف العربي للفيديو"),
            "tr": ("Türkçe Başlık", "Türkçe video açıklaması")
        ]
        
        if let translation = mockTranslations[languageCode] {
            return (translation.title, translation.description, tags) // Tags remain same for simplicity
        } else {
            return ("[Translated] \(title)", "[Translated] \(description)", tags)
        }
    }
    
    // MARK: - Bulk Operations
    
    func translateToPopularLanguages(videoId: String, originalTitle: String, originalDescription: String, originalTags: [String]) async {
        let popularLanguages = ["es", "fr", "de", "pt", "ru", "ja", "ko", "zh", "hi", "ar"]
        await autoTranslate(
            videoId: videoId,
            originalTitle: originalTitle,
            originalDescription: originalDescription,
            originalTags: originalTags,
            to: popularLanguages
        )
    }
    
    func getTranslation(for videoId: String, languageCode: String) -> VideoTranslation? {
        return videoTranslations[videoId]?.translations[languageCode]
    }
    
    func getAvailableLanguages(for videoId: String) -> [SupportedLanguage] {
        guard let metadata = videoTranslations[videoId] else { return [] }
        
        return SupportedLanguage.supportedLanguages.filter { language in
            metadata.translations.keys.contains(language.code)
        }
    }
    
    func getMissingLanguages(for videoId: String) -> [SupportedLanguage] {
        guard let metadata = videoTranslations[videoId] else { return SupportedLanguage.supportedLanguages }
        
        return SupportedLanguage.supportedLanguages.filter { language in
            !metadata.translations.keys.contains(language.code)
        }
    }
    
    // MARK: - Analytics
    
    func getTranslationStats(for videoId: String) -> TranslationStats {
        guard let metadata = videoTranslations[videoId] else {
            return TranslationStats()
        }
        
        return TranslationStats(
            totalLanguages: metadata.translations.count,
            autoTranslated: metadata.autoTranslatedLanguages.count,
            manuallyTranslated: metadata.manuallyTranslatedLanguages.count,
            completionPercentage: Double(metadata.translations.count) / Double(SupportedLanguage.supportedLanguages.count)
        )
    }
    
    // MARK: - Persistence
    
    private func saveMetadata(_ metadata: MultiLanguageMetadata) async {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let data = try JSONEncoder().encode(metadata)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            try await db.collection("multiLanguageMetadata").document(metadata.videoId).setData(dict)
        } catch {
            print("Error saving multi-language metadata: \(error)")
        }
        #endif
    }
}

// MARK: - Supporting Types

struct TranslationStats {
    let totalLanguages: Int
    let autoTranslated: Int
    let manuallyTranslated: Int
    let completionPercentage: Double
    
    init(totalLanguages: Int = 0, autoTranslated: Int = 0, manuallyTranslated: Int = 0, completionPercentage: Double = 0.0) {
        self.totalLanguages = totalLanguages
        self.autoTranslated = autoTranslated
        self.manuallyTranslated = manuallyTranslated
        self.completionPercentage = completionPercentage
    }
}
