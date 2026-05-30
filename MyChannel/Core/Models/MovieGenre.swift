import Foundation

extension FreeMovie {
    enum MovieGenre: String, CaseIterable, Codable {
        case action = "action"
        case comedy = "comedy"
        case drama = "drama"
        case horror = "horror"
        case thriller = "thriller"
        case romance = "romance"
        case scifi = "sci-fi"
        case fantasy = "fantasy"
        case documentary = "documentary"
        case animation = "animation"
        case crime = "crime"
        case mystery = "mystery"
        case adventure = "adventure"
        case family = "family"
        case western = "western"
        case war = "war"
        case musical = "musical"
        case biography = "biography"
    
        var displayName: String {
            switch self {
            case .action: return "🎬 Action"
            case .comedy: return "😂 Comedy"
            case .drama: return "🎭 Drama"
            case .horror: return "👻 Horror"
            case .thriller: return "😱 Thriller"
            case .romance: return "💕 Romance"
            case .scifi: return "🚀 Sci-Fi"
            case .fantasy: return "🧙‍♂️ Fantasy"
            case .documentary: return "📽️ Documentary"
            case .animation: return "🎨 Animation"
            case .crime: return "🔍 Crime"
            case .mystery: return "🕵️ Mystery"
            case .adventure: return "🗺️ Adventure"
            case .family: return "👨‍👩‍👧‍👦 Family"
            case .western: return "🤠 Western"
            case .war: return "⚔️ War"
            case .musical: return "🎵 Musical"
            case .biography: return "📚 Biography"
            }
        }
    }

}