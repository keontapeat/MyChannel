//
//  RealTimeTranslationViewModel.swift
//  MyChannel
//
//  ViewModel for Real-Time Translation
//

import Foundation

struct TranslationLanguage: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let nativeName: String
    let code: String
    let flag: String
    let speakers: String
}

@MainActor
class RealTimeTranslationViewModel: ObservableObject {
    @Published var currentLanguage: TranslationLanguage
    @Published var allLanguages: [TranslationLanguage] = []
    @Published var popularLanguages: [TranslationLanguage] = []
    @Published var recentLanguages: [TranslationLanguage] = []
    
    @Published var totalTranslations: Int = 0
    @Published var hoursTranslated: Int = 0
    @Published var languagesUsed: Int = 0
    
    init() {
        // Default to English
        self.currentLanguage = TranslationLanguage(
            id: "en",
            name: "English",
            nativeName: "English",
            code: "en",
            flag: "🇺🇸",
            speakers: "1.5B"
        )
    }
    
    func loadTranslationData() async {
        // Stats
        totalTranslations = 1284
        hoursTranslated = 47
        languagesUsed = 12
        
        // Popular languages
        popularLanguages = [
            TranslationLanguage(id: "es", name: "Spanish", nativeName: "Español", code: "es", flag: "🇪🇸", speakers: "559M"),
            TranslationLanguage(id: "zh", name: "Chinese", nativeName: "中文", code: "zh", flag: "🇨🇳", speakers: "1.3B"),
            TranslationLanguage(id: "fr", name: "French", nativeName: "Français", code: "fr", flag: "🇫🇷", speakers: "280M"),
            TranslationLanguage(id: "de", name: "German", nativeName: "Deutsch", code: "de", flag: "🇩🇪", speakers: "134M"),
            TranslationLanguage(id: "ja", name: "Japanese", nativeName: "日本語", code: "ja", flag: "🇯🇵", speakers: "125M"),
            TranslationLanguage(id: "ko", name: "Korean", nativeName: "한국어", code: "ko", flag: "🇰🇷", speakers: "81M"),
            TranslationLanguage(id: "pt", name: "Portuguese", nativeName: "Português", code: "pt", flag: "🇧🇷", speakers: "264M"),
            TranslationLanguage(id: "ar", name: "Arabic", nativeName: "العربية", code: "ar", flag: "🇸🇦", speakers: "422M")
        ]
        
        // Recent languages
        recentLanguages = Array(popularLanguages.prefix(3))
        
        // All 100+ languages
        allLanguages = [
            // Major languages
            TranslationLanguage(id: "en", name: "English", nativeName: "English", code: "en", flag: "🇺🇸", speakers: "1.5B"),
            TranslationLanguage(id: "zh", name: "Chinese (Mandarin)", nativeName: "中文", code: "zh", flag: "🇨🇳", speakers: "1.3B"),
            TranslationLanguage(id: "hi", name: "Hindi", nativeName: "हिन्दी", code: "hi", flag: "🇮🇳", speakers: "602M"),
            TranslationLanguage(id: "es", name: "Spanish", nativeName: "Español", code: "es", flag: "🇪🇸", speakers: "559M"),
            TranslationLanguage(id: "fr", name: "French", nativeName: "Français", code: "fr", flag: "🇫🇷", speakers: "280M"),
            TranslationLanguage(id: "ar", name: "Arabic", nativeName: "العربية", code: "ar", flag: "🇸🇦", speakers: "422M"),
            TranslationLanguage(id: "bn", name: "Bengali", nativeName: "বাংলা", code: "bn", flag: "🇧🇩", speakers: "272M"),
            TranslationLanguage(id: "pt", name: "Portuguese", nativeName: "Português", code: "pt", flag: "🇧🇷", speakers: "264M"),
            TranslationLanguage(id: "ru", name: "Russian", nativeName: "Русский", code: "ru", flag: "🇷🇺", speakers: "258M"),
            TranslationLanguage(id: "ja", name: "Japanese", nativeName: "日本語", code: "ja", flag: "🇯🇵", speakers: "125M"),
            
            // European languages
            TranslationLanguage(id: "de", name: "German", nativeName: "Deutsch", code: "de", flag: "🇩🇪", speakers: "134M"),
            TranslationLanguage(id: "it", name: "Italian", nativeName: "Italiano", code: "it", flag: "🇮🇹", speakers: "67M"),
            TranslationLanguage(id: "pl", name: "Polish", nativeName: "Polski", code: "pl", flag: "🇵🇱", speakers: "45M"),
            TranslationLanguage(id: "uk", name: "Ukrainian", nativeName: "Українська", code: "uk", flag: "🇺🇦", speakers: "40M"),
            TranslationLanguage(id: "ro", name: "Romanian", nativeName: "Română", code: "ro", flag: "🇷🇴", speakers: "24M"),
            TranslationLanguage(id: "nl", name: "Dutch", nativeName: "Nederlands", code: "nl", flag: "🇳🇱", speakers: "25M"),
            TranslationLanguage(id: "el", name: "Greek", nativeName: "Ελληνικά", code: "el", flag: "🇬🇷", speakers: "13M"),
            TranslationLanguage(id: "cs", name: "Czech", nativeName: "Čeština", code: "cs", flag: "🇨🇿", speakers: "10M"),
            TranslationLanguage(id: "sv", name: "Swedish", nativeName: "Svenska", code: "sv", flag: "🇸🇪", speakers: "13M"),
            TranslationLanguage(id: "hu", name: "Hungarian", nativeName: "Magyar", code: "hu", flag: "🇭🇺", speakers: "13M"),
            
            // Asian languages
            TranslationLanguage(id: "ko", name: "Korean", nativeName: "한국어", code: "ko", flag: "🇰🇷", speakers: "81M"),
            TranslationLanguage(id: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", code: "vi", flag: "🇻🇳", speakers: "85M"),
            TranslationLanguage(id: "th", name: "Thai", nativeName: "ไทย", code: "th", flag: "🇹🇭", speakers: "61M"),
            TranslationLanguage(id: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", code: "id", flag: "🇮🇩", speakers: "199M"),
            TranslationLanguage(id: "tr", name: "Turkish", nativeName: "Türkçe", code: "tr", flag: "🇹🇷", speakers: "88M"),
            TranslationLanguage(id: "fa", name: "Persian", nativeName: "فارسی", code: "fa", flag: "🇮🇷", speakers: "110M"),
            TranslationLanguage(id: "he", name: "Hebrew", nativeName: "עברית", code: "he", flag: "🇮🇱", speakers: "9M"),
            
            // Additional 70+ languages
            TranslationLanguage(id: "af", name: "Afrikaans", nativeName: "Afrikaans", code: "af", flag: "🇿🇦", speakers: "7M"),
            TranslationLanguage(id: "sq", name: "Albanian", nativeName: "Shqip", code: "sq", flag: "🇦🇱", speakers: "8M"),
            TranslationLanguage(id: "am", name: "Amharic", nativeName: "አማርኛ", code: "am", flag: "🇪🇹", speakers: "32M"),
            TranslationLanguage(id: "hy", name: "Armenian", nativeName: "Հայերեն", code: "hy", flag: "🇦🇲", speakers: "6M"),
            TranslationLanguage(id: "az", name: "Azerbaijani", nativeName: "Azərbaycan", code: "az", flag: "🇦🇿", speakers: "33M"),
            TranslationLanguage(id: "eu", name: "Basque", nativeName: "Euskara", code: "eu", flag: "🏴", speakers: "1M"),
            TranslationLanguage(id: "be", name: "Belarusian", nativeName: "Беларуская", code: "be", flag: "🇧🇾", speakers: "7M"),
            TranslationLanguage(id: "bs", name: "Bosnian", nativeName: "Bosanski", code: "bs", flag: "🇧🇦", speakers: "3M"),
            TranslationLanguage(id: "bg", name: "Bulgarian", nativeName: "Български", code: "bg", flag: "🇧🇬", speakers: "8M"),
            TranslationLanguage(id: "ca", name: "Catalan", nativeName: "Català", code: "ca", flag: "🏴", speakers: "10M"),
            TranslationLanguage(id: "hr", name: "Croatian", nativeName: "Hrvatski", code: "hr", flag: "🇭🇷", speakers: "5M"),
            TranslationLanguage(id: "da", name: "Danish", nativeName: "Dansk", code: "da", flag: "🇩🇰", speakers: "6M"),
            TranslationLanguage(id: "et", name: "Estonian", nativeName: "Eesti", code: "et", flag: "🇪🇪", speakers: "1M"),
            TranslationLanguage(id: "fi", name: "Finnish", nativeName: "Suomi", code: "fi", flag: "🇫🇮", speakers: "5M"),
            TranslationLanguage(id: "gl", name: "Galician", nativeName: "Galego", code: "gl", flag: "🏴", speakers: "2M"),
            TranslationLanguage(id: "ka", name: "Georgian", nativeName: "ქართული", code: "ka", flag: "🇬🇪", speakers: "4M"),
            TranslationLanguage(id: "gu", name: "Gujarati", nativeName: "ગુજરાતી", code: "gu", flag: "🇮🇳", speakers: "60M"),
            TranslationLanguage(id: "ht", name: "Haitian Creole", nativeName: "Kreyòl", code: "ht", flag: "🇭🇹", speakers: "12M"),
            TranslationLanguage(id: "ha", name: "Hausa", nativeName: "Hausa", code: "ha", flag: "🇳🇬", speakers: "85M"),
            TranslationLanguage(id: "is", name: "Icelandic", nativeName: "Íslenska", code: "is", flag: "🇮🇸", speakers: "360K"),
            TranslationLanguage(id: "ig", name: "Igbo", nativeName: "Igbo", code: "ig", flag: "🇳🇬", speakers: "31M"),
            TranslationLanguage(id: "ga", name: "Irish", nativeName: "Gaeilge", code: "ga", flag: "🇮🇪", speakers: "1M"),
            TranslationLanguage(id: "jv", name: "Javanese", nativeName: "Basa Jawa", code: "jv", flag: "🇮🇩", speakers: "84M"),
            TranslationLanguage(id: "kn", name: "Kannada", nativeName: "ಕನ್ನಡ", code: "kn", flag: "🇮🇳", speakers: "48M"),
            TranslationLanguage(id: "kk", name: "Kazakh", nativeName: "Қазақ", code: "kk", flag: "🇰🇿", speakers: "18M"),
            TranslationLanguage(id: "km", name: "Khmer", nativeName: "ខ្មែរ", code: "km", flag: "🇰🇭", speakers: "16M"),
            TranslationLanguage(id: "rw", name: "Kinyarwanda", nativeName: "Kinyarwanda", code: "rw", flag: "🇷🇼", speakers: "12M"),
            TranslationLanguage(id: "ku", name: "Kurdish", nativeName: "Kurdî", code: "ku", flag: "🏴", speakers: "30M"),
            TranslationLanguage(id: "ky", name: "Kyrgyz", nativeName: "Кыргызча", code: "ky", flag: "🇰🇬", speakers: "5M"),
            TranslationLanguage(id: "lo", name: "Lao", nativeName: "ລາວ", code: "lo", flag: "🇱🇦", speakers: "30M"),
            TranslationLanguage(id: "lv", name: "Latvian", nativeName: "Latviešu", code: "lv", flag: "🇱🇻", speakers: "2M"),
            TranslationLanguage(id: "lt", name: "Lithuanian", nativeName: "Lietuvių", code: "lt", flag: "🇱🇹", speakers: "3M"),
            TranslationLanguage(id: "mk", name: "Macedonian", nativeName: "Македонски", code: "mk", flag: "🇲🇰", speakers: "2M"),
            TranslationLanguage(id: "mg", name: "Malagasy", nativeName: "Malagasy", code: "mg", flag: "🇲🇬", speakers: "25M"),
            TranslationLanguage(id: "ms", name: "Malay", nativeName: "Bahasa Melayu", code: "ms", flag: "🇲🇾", speakers: "290M"),
            TranslationLanguage(id: "ml", name: "Malayalam", nativeName: "മലയാളം", code: "ml", flag: "🇮🇳", speakers: "38M"),
            TranslationLanguage(id: "mt", name: "Maltese", nativeName: "Malti", code: "mt", flag: "🇲🇹", speakers: "520K"),
            TranslationLanguage(id: "mi", name: "Maori", nativeName: "Te Reo Māori", code: "mi", flag: "🇳🇿", speakers: "186K"),
            TranslationLanguage(id: "mr", name: "Marathi", nativeName: "मराठी", code: "mr", flag: "🇮🇳", speakers: "95M"),
            TranslationLanguage(id: "mn", name: "Mongolian", nativeName: "Монгол", code: "mn", flag: "🇲🇳", speakers: "5M"),
            TranslationLanguage(id: "my", name: "Myanmar (Burmese)", nativeName: "မြန်မာ", code: "my", flag: "🇲🇲", speakers: "33M"),
            TranslationLanguage(id: "ne", name: "Nepali", nativeName: "नेपाली", code: "ne", flag: "🇳🇵", speakers: "16M"),
            TranslationLanguage(id: "no", name: "Norwegian", nativeName: "Norsk", code: "no", flag: "🇳🇴", speakers: "5M"),
            TranslationLanguage(id: "ny", name: "Nyanja (Chichewa)", nativeName: "Chichewa", code: "ny", flag: "🇲🇼", speakers: "12M"),
            TranslationLanguage(id: "or", name: "Odia (Oriya)", nativeName: "ଓଡ଼ିଆ", code: "or", flag: "🇮🇳", speakers: "38M"),
            TranslationLanguage(id: "ps", name: "Pashto", nativeName: "پښتو", code: "ps", flag: "🇦🇫", speakers: "60M"),
            TranslationLanguage(id: "pa", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ", code: "pa", flag: "🇮🇳", speakers: "125M"),
            TranslationLanguage(id: "sr", name: "Serbian", nativeName: "Српски", code: "sr", flag: "🇷🇸", speakers: "12M"),
            TranslationLanguage(id: "st", name: "Sesotho", nativeName: "Sesotho", code: "st", flag: "🇱🇸", speakers: "7M"),
            TranslationLanguage(id: "sn", name: "Shona", nativeName: "Shona", code: "sn", flag: "🇿🇼", speakers: "14M"),
            TranslationLanguage(id: "sd", name: "Sindhi", nativeName: "سنڌي", code: "sd", flag: "🇵🇰", speakers: "30M"),
            TranslationLanguage(id: "si", name: "Sinhala", nativeName: "සිංහල", code: "si", flag: "🇱🇰", speakers: "17M"),
            TranslationLanguage(id: "sk", name: "Slovak", nativeName: "Slovenčina", code: "sk", flag: "🇸🇰", speakers: "5M"),
            TranslationLanguage(id: "sl", name: "Slovenian", nativeName: "Slovenščina", code: "sl", flag: "🇸🇮", speakers: "2M"),
            TranslationLanguage(id: "so", name: "Somali", nativeName: "Soomaali", code: "so", flag: "🇸🇴", speakers: "21M"),
            TranslationLanguage(id: "su", name: "Sundanese", nativeName: "Basa Sunda", code: "su", flag: "🇮🇩", speakers: "42M"),
            TranslationLanguage(id: "sw", name: "Swahili", nativeName: "Kiswahili", code: "sw", flag: "🇰🇪", speakers: "200M"),
            TranslationLanguage(id: "tl", name: "Tagalog (Filipino)", nativeName: "Tagalog", code: "tl", flag: "🇵🇭", speakers: "82M"),
            TranslationLanguage(id: "tg", name: "Tajik", nativeName: "Тоҷикӣ", code: "tg", flag: "🇹🇯", speakers: "8M"),
            TranslationLanguage(id: "ta", name: "Tamil", nativeName: "தமிழ்", code: "ta", flag: "🇮🇳", speakers: "81M"),
            TranslationLanguage(id: "tt", name: "Tatar", nativeName: "Татар", code: "tt", flag: "🇷🇺", speakers: "5M"),
            TranslationLanguage(id: "te", name: "Telugu", nativeName: "తెలుగు", code: "te", flag: "🇮🇳", speakers: "93M"),
            TranslationLanguage(id: "tk", name: "Turkmen", nativeName: "Türkmen", code: "tk", flag: "🇹🇲", speakers: "7M"),
            TranslationLanguage(id: "ur", name: "Urdu", nativeName: "اردو", code: "ur", flag: "🇵🇰", speakers: "232M"),
            TranslationLanguage(id: "ug", name: "Uyghur", nativeName: "ئۇيغۇرچە", code: "ug", flag: "🇨🇳", speakers: "10M"),
            TranslationLanguage(id: "uz", name: "Uzbek", nativeName: "Oʻzbek", code: "uz", flag: "🇺🇿", speakers: "44M"),
            TranslationLanguage(id: "cy", name: "Welsh", nativeName: "Cymraeg", code: "cy", flag: "🏴󠁧󠁢󠁷󠁬󠁳󠁿", speakers: "900K"),
            TranslationLanguage(id: "xh", name: "Xhosa", nativeName: "isiXhosa", code: "xh", flag: "🇿🇦", speakers: "8M"),
            TranslationLanguage(id: "yi", name: "Yiddish", nativeName: "ייִדיש", code: "yi", flag: "🏴", speakers: "1M"),
            TranslationLanguage(id: "yo", name: "Yoruba", nativeName: "Yorùbá", code: "yo", flag: "🇳🇬", speakers: "45M"),
            TranslationLanguage(id: "zu", name: "Zulu", nativeName: "isiZulu", code: "zu", flag: "🇿🇦", speakers: "14M")
        ].sorted { $0.name < $1.name }
    }
    
    func setCurrentLanguage(_ language: TranslationLanguage) {
        currentLanguage = language
        
        // Add to recent if not already there
        if !recentLanguages.contains(where: { $0.id == language.id }) {
            recentLanguages.insert(language, at: 0)
            if recentLanguages.count > 5 {
                recentLanguages.removeLast()
            }
        }
    }
}

