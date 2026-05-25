import Foundation

struct LocalizedContent: Codable {
    let videoId: String
    let locale: String
    let title: String
    let description: String
    let tags: [String]
    let thumbnailURL: String?
    let generatedAt: Date
    let source: LocalizationSource
    
    enum LocalizationSource: String, Codable {
        case ai, human, hybrid
    }
}

struct ASOMeta: Codable {
    let appId: String
    let locale: String
    let title: String
    let subtitle: String
    let keywords: [String]
    let description: String
    let screenshotCaptions: [String]
    let promoText: String?
    let lastUpdated: Date
    let performance: ASOPerformance?
    
    struct ASOPerformance: Codable {
        let impressions: Int
        let conversionRate: Double
        let keywordRankings: [String: Int]
        let competitorAnalysis: [String: Double]
    }
}

@MainActor
final class LocalizationService: ObservableObject {
    static let shared = LocalizationService()
    private init() {}
    
    @Published var supportedLocales: [String] = [
        "en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR", 
        "ja-JP", "ko-KR", "zh-CN", "ar-SA", "hi-IN", "ru-RU"
    ]
    
    func localizeVideoContent(videoId: String, originalTitle: String, originalDescription: String, originalTags: [String], targetLocales: [String]) async -> [LocalizedContent] {
        var results: [LocalizedContent] = []
        
        for locale in targetLocales {
            // Simulate AI translation/localization
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let localized = LocalizedContent(
                videoId: videoId,
                locale: locale,
                title: await translateTitle(originalTitle, to: locale),
                description: await translateDescription(originalDescription, to: locale),
                tags: await localizeTags(originalTags, to: locale),
                thumbnailURL: nil,
                generatedAt: Date(),
                source: .ai
            )
            
            results.append(localized)
        }
        
        return results
    }
    
    func generateASOMetadata(for locale: String, category: String, keywords: [String]) async -> ASOMeta {
        // Simulate ASO generation
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let localizedKeywords = await localizeKeywords(keywords, to: locale)
        
        return ASOMeta(
            appId: Bundle.main.bundleIdentifier ?? "",
            locale: locale,
            title: await generateLocalizedAppTitle(for: locale),
            subtitle: await generateLocalizedSubtitle(for: locale, category: category),
            keywords: localizedKeywords,
            description: await generateLocalizedDescription(for: locale),
            screenshotCaptions: await generateScreenshotCaptions(for: locale),
            promoText: await generatePromoText(for: locale),
            lastUpdated: Date(),
            performance: nil
        )
    }
    
    func rotateASOContent(locale: String, testVariants: [ASOMeta]) async -> ASOMeta? {
        // A/B test different ASO variants and return the winner
        let winner = testVariants.randomElement()
        
        // Would track performance and select based on conversion rates
        return winner
    }
    
    private func translateTitle(_ title: String, to locale: String) async -> String {
        // Mock translation based on locale
        switch locale {
        case "es-ES", "es-MX": return "Título en Español: \(title)"
        case "fr-FR": return "Titre Français: \(title)"
        case "de-DE": return "Deutscher Titel: \(title)"
        case "ja-JP": return "日本語タイトル: \(title)"
        case "ko-KR": return "한국어 제목: \(title)"
        case "zh-CN": return "中文标题: \(title)"
        case "pt-BR": return "Título em Português: \(title)"
        case "ru-RU": return "Русский заголовок: \(title)"
        case "ar-SA": return "العنوان العربي: \(title)"
        case "hi-IN": return "हिंदी शीर्षक: \(title)"
        case "it-IT": return "Titolo Italiano: \(title)"
        default: return title
        }
    }
    
    private func translateDescription(_ description: String, to locale: String) async -> String {
        // Mock translation - in production would use Google Translate API
        switch locale {
        case "es-ES": return "Descripción en español de este contenido..."
        case "fr-FR": return "Description française de ce contenu..."
        case "de-DE": return "Deutsche Beschreibung dieses Inhalts..."
        case "ja-JP": return "このコンテンツの日本語説明..."
        case "ko-KR": return "이 콘텐츠에 대한 한국어 설명..."
        case "zh-CN": return "此内容的中文描述..."
        default: return description
        }
    }
    
    private func localizeTags(_ tags: [String], to locale: String) async -> [String] {
        // Translate and localize tags
        let localizedTags = await generateLocalizedTags(for: locale)
        return tags + localizedTags
    }
    
    private func localizeKeywords(_ keywords: [String], to locale: String) async -> [String] {
        var localized = keywords
        
        // Add locale-specific trending keywords
        switch locale {
        case "ja-JP": localized += ["動画", "エンターテイメント", "音楽"]
        case "ko-KR": localized += ["비디오", "엔터테인먼트", "음악"]
        case "es-ES": localized += ["vídeo", "entretenimiento", "música"]
        case "fr-FR": localized += ["vidéo", "divertissement", "musique"]
        default: break
        }
        
        return Array(Set(localized)) // Remove duplicates
    }
    
    private func generateLocalizedTags(for locale: String) -> [String] {
        switch locale {
        case "ja-JP": return ["人気", "トレンド", "新着"]
        case "ko-KR": return ["인기", "트렌딩", "신규"]
        case "es-ES": return ["popular", "tendencia", "nuevo"]
        case "fr-FR": return ["populaire", "tendance", "nouveau"]
        default: return ["trending", "popular", "new"]
        }
    }
    
    private func generateLocalizedAppTitle(for locale: String) -> String {
        switch locale {
        case "es-ES": return "MyChannel - Videos y Entretenimiento"
        case "fr-FR": return "MyChannel - Vidéos et Divertissement"
        case "de-DE": return "MyChannel - Videos und Unterhaltung"
        case "ja-JP": return "MyChannel - 動画とエンターテイメント"
        case "ko-KR": return "MyChannel - 동영상 및 엔터테인먼트"
        case "zh-CN": return "MyChannel - 视频与娱乐"
        default: return "MyChannel - Video & Entertainment"
        }
    }
    
    private func generateLocalizedSubtitle(for locale: String, category: String) -> String {
        switch locale {
        case "es-ES": return "Descubre videos increíbles"
        case "fr-FR": return "Découvrez des vidéos incroyables"
        case "de-DE": return "Entdecke großartige Videos"
        case "ja-JP": return "素晴らしい動画を発見"
        case "ko-KR": return "놀라운 동영상 발견"
        case "zh-CN": return "发现精彩视频"
        default: return "Discover amazing videos"
        }
    }
    
    private func generateLocalizedDescription(for locale: String) -> String {
        switch locale {
        case "es-ES": return "MyChannel es la plataforma definitiva para videos, entretenimiento y contenido creativo..."
        case "fr-FR": return "MyChannel est la plateforme ultime pour les vidéos, le divertissement et le contenu créatif..."
        case "de-DE": return "MyChannel ist die ultimative Plattform für Videos, Unterhaltung und kreativen Inhalt..."
        default: return "MyChannel is the ultimate platform for videos, entertainment, and creative content..."
        }
    }
    
    private func generateScreenshotCaptions(for locale: String) -> [String] {
        switch locale {
        case "es-ES": return ["Descubre contenido increíble", "Crea y comparte videos", "Conecta con creadores"]
        case "fr-FR": return ["Découvrez un contenu incroyable", "Créez et partagez des vidéos", "Connectez-vous avec des créateurs"]
        default: return ["Discover amazing content", "Create and share videos", "Connect with creators"]
        }
    }
    
    private func generatePromoText(for locale: String) -> String {
        switch locale {
        case "es-ES": return "¡Únete a millones de creadores!"
        case "fr-FR": return "Rejoignez des millions de créateurs!"
        case "de-DE": return "Treten Sie Millionen von Erstellern bei!"
        default: return "Join millions of creators!"
        }
    }
}
