//
//  CareerPathModels.swift
//  MyChannel
//
//  Revolutionary Career Path System for MyChannel University
//  AI-Tracked Learning with LinkedIn-Ready Credentials
//

import Foundation
import SwiftUI

// MARK: - Career Path

/// Represents a complete career field (e.g., Accounting, Film Production, Software Engineering)
struct CareerPath: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: CareerCategory
    let icon: String
    let color: Color
    let keywords: [String] // For AI categorization
    let certificateRequirement: CertificateRequirement
    let skillTags: [String] // Specific skills in this career
    
    init(
        id: String,
        name: String,
        description: String,
        category: CareerCategory,
        icon: String,
        color: Color,
        keywords: [String],
        certificateRequirement: CertificateRequirement,
        skillTags: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.icon = icon
        self.color = color
        self.keywords = keywords
        self.certificateRequirement = certificateRequirement
        self.skillTags = skillTags
    }
    
    static func == (lhs: CareerPath, rhs: CareerPath) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Career Category

enum CareerCategory: String, CaseIterable, Codable {
    case business = "Business & Finance"
    case technology = "Technology & Software"
    case creative = "Creative & Media"
    case health = "Health & Wellness"
    case trades = "Skilled Trades"
    case education = "Education & Teaching"
    case marketing = "Marketing & Sales"
    case design = "Design & UX"
    case engineering = "Engineering"
    case science = "Science & Research"
    case legal = "Legal & Compliance"
    case hospitality = "Hospitality & Service"
    
    var icon: String {
        switch self {
        case .business: return "briefcase.fill"
        case .technology: return "laptopcomputer"
        case .creative: return "film.fill"
        case .health: return "heart.text.square.fill"
        case .trades: return "hammer.fill"
        case .education: return "book.fill"
        case .marketing: return "megaphone.fill"
        case .design: return "paintbrush.fill"
        case .engineering: return "gearshape.2.fill"
        case .science: return "atom"
        case .legal: return "scale.3d"
        case .hospitality: return "fork.knife"
        }
    }
    
    var color: Color {
        switch self {
        case .business: return Color(red: 0.2, green: 0.4, blue: 0.8)
        case .technology: return Color(red: 0.0, green: 0.7, blue: 0.4)
        case .creative: return Color(red: 0.6, green: 0.2, blue: 0.8)
        case .health: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .trades: return Color(red: 0.7, green: 0.5, blue: 0.2)
        case .education: return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .marketing: return Color(red: 0.9, green: 0.5, blue: 0.2)
        case .design: return Color(red: 0.8, green: 0.2, blue: 0.5)
        case .engineering: return Color(red: 0.4, green: 0.6, blue: 0.8)
        case .science: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case .legal: return Color(red: 0.5, green: 0.4, blue: 0.7)
        case .hospitality: return Color(red: 0.9, green: 0.6, blue: 0.3)
        }
    }
}

// MARK: - Certificate Requirement

struct CertificateRequirement: Codable, Hashable {
    let minimumVideos: Int
    let minimumHours: Double
    let minimumAIScore: Int // 0-100
    let requiredSkills: [String] // Must watch videos covering these skills
    
    init(minimumVideos: Int = 300, minimumHours: Double = 250, minimumAIScore: Int = 70, requiredSkills: [String] = []) {
        self.minimumVideos = minimumVideos
        self.minimumHours = minimumHours
        self.minimumAIScore = minimumAIScore
        self.requiredSkills = requiredSkills
    }
}

// MARK: - Career Path Progress

/// User's progress in a specific career path
struct CareerPathProgress: Identifiable, Codable {
    let id: String
    let userId: String
    let careerPathId: String
    var totalHours: Double
    var videosWatched: Int
    var videoIds: [String] // All watched video IDs
    var lastWatchedAt: Date
    var certificateProgress: Double // 0.0 - 1.0
    var certificateEarned: Bool
    var certificateEarnedDate: Date?
    var averageAIScore: Int // 0-100
    var skillsCovered: Set<String> // Skills user has learned
    
    var hoursRemaining: Double {
        max(0, 250 - totalHours) // Default 250 hours for certificate
    }
    
    var videosRemaining: Int {
        max(0, 300 - videosWatched) // Default 300 videos for certificate
    }
    
    var progressPercentage: Int {
        Int(certificateProgress * 100)
    }
}

// MARK: - University Video

/// Extended video model with career path tags and AI verification
struct UniversityVideo: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let videoId: String // Original video ID
    let title: String
    let thumbnailURL: String
    let duration: TimeInterval
    let creatorId: String
    let creatorName: String
    let creatorAvatarURL: String
    
    // University-specific fields
    var careerPaths: [String] // Career path IDs this video teaches
    var skillTags: [String] // Specific skills covered
    var difficultyLevel: DifficultyLevel
    var isUniversityContent: Bool // Creator-tagged as University content
    var certificateEligible: Bool
    var aiCategorizationScore: Double // Confidence 0.0-1.0
    
    // User progress
    var watchProgress: Double // 0.0 - 1.0
    var lastWatchedAt: Date?
    var aiVerificationScore: Int? // 0-100
    var completed: Bool
    
    enum DifficultyLevel: String, Codable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .blue
            case .advanced: return .orange
            case .expert: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .beginner: return "1.circle.fill"
            case .intermediate: return "2.circle.fill"
            case .advanced: return "3.circle.fill"
            case .expert: return "star.fill"
            }
        }
    }
}

// MARK: - University Certificate

/// Earned certificate for completing a career path
struct UniversityCertificate: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let careerPathId: String
    let careerPathName: String
    let totalHours: Double
    let videosCompleted: Int
    let averageAIScore: Int
    let earnedDate: Date
    let verificationHash: String? // Blockchain verification (future)
    let certificateNumber: String
    let skillsAcquired: [String]
    
    var certificateCode: String {
        "MCU-\(careerPathId.prefix(4).uppercased())-\(certificateNumber)"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: earnedDate)
    }
}

// MARK: - Continue Learning Video

/// Video user can continue watching (incomplete)
struct ContinueLearningVideo: Identifiable {
    let id: String
    let video: UniversityVideo
    let careerPathId: String
    let careerPathName: String
    let careerPathColor: Color
    let progressPercentage: Double // 0.0 - 1.0
    let timeRemaining: TimeInterval
    let lastWatchedAt: Date
    
    var progressText: String {
        "\(Int(progressPercentage * 100))% complete"
    }
    
    var timeRemainingText: String {
        let minutes = Int(timeRemaining / 60)
        if minutes < 60 {
            return "\(minutes) min left"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m left"
        }
    }
}

// MARK: - Top Creator in Career Path

struct CareerPathCreator: Identifiable, Codable {
    let id: String
    let creatorId: String
    let name: String
    let avatarURL: String
    let careerPathId: String
    let videosCount: Int
    let totalHours: Double
    let averageRating: Double
    let subscriberCount: Int
    let isVerified: Bool
}

// MARK: - Predefined Career Paths

extension CareerPath {
    static let allCareerPaths: [CareerPath] = [
        // Business & Finance
        CareerPath(
            id: "accounting",
            name: "Accounting & Finance",
            description: "Master accounting principles, financial analysis, tax planning, and bookkeeping",
            category: .business,
            icon: "chart.bar.doc.horizontal.fill",
            color: Color(red: 0.2, green: 0.4, blue: 0.8),
            keywords: ["accounting", "finance", "bookkeeping", "tax", "cpa", "financial analysis", "audit", "quickbooks", "excel"],
            certificateRequirement: CertificateRequirement(minimumVideos: 300, minimumHours: 250, minimumAIScore: 70, requiredSkills: ["accounting basics", "financial statements", "tax preparation"]),
            skillTags: ["Accounting", "Tax Preparation", "Financial Analysis", "QuickBooks", "Excel", "Bookkeeping", "Audit"]
        ),
        
        // Creative & Media
        CareerPath(
            id: "film-production",
            name: "Film Production & Video Editing",
            description: "Learn cinematography, video editing, color grading, and film production",
            category: .creative,
            icon: "film.fill",
            color: Color(red: 0.6, green: 0.2, blue: 0.8),
            keywords: ["film", "video editing", "cinematography", "premiere pro", "final cut", "davinci resolve", "color grading", "filmmaking", "production"],
            certificateRequirement: CertificateRequirement(minimumVideos: 350, minimumHours: 300, minimumAIScore: 75, requiredSkills: ["video editing", "cinematography", "color grading"]),
            skillTags: ["Video Editing", "Cinematography", "Color Grading", "Premiere Pro", "Final Cut Pro", "DaVinci Resolve", "Lighting", "Sound Design"]
        ),
        
        // Technology & Software
        CareerPath(
            id: "software-engineering",
            name: "Software Engineering",
            description: "Master programming, algorithms, system design, and software development",
            category: .technology,
            icon: "laptopcomputer.and.iphone",
            color: Color(red: 0.0, green: 0.7, blue: 0.4),
            keywords: ["programming", "coding", "software", "javascript", "python", "java", "react", "development", "algorithms", "data structures"],
            certificateRequirement: CertificateRequirement(minimumVideos: 400, minimumHours: 350, minimumAIScore: 80, requiredSkills: ["programming fundamentals", "algorithms", "system design"]),
            skillTags: ["Programming", "JavaScript", "Python", "React", "Algorithms", "System Design", "Git", "Testing"]
        ),
        
        CareerPath(
            id: "ios-development",
            name: "iOS Development",
            description: "Build iOS apps with Swift, SwiftUI, and master App Store deployment",
            category: .technology,
            icon: "apple.logo",
            color: Color(red: 0.0, green: 0.5, blue: 0.9),
            keywords: ["ios", "swift", "swiftui", "xcode", "app development", "iphone", "mobile"],
            certificateRequirement: CertificateRequirement(minimumVideos: 320, minimumHours: 280, minimumAIScore: 75, requiredSkills: ["swift basics", "swiftui", "app architecture"]),
            skillTags: ["Swift", "SwiftUI", "UIKit", "Xcode", "App Store", "iOS Design", "Core Data"]
        ),
        
        // Marketing & Sales
        CareerPath(
            id: "digital-marketing",
            name: "Digital Marketing",
            description: "Master SEO, social media marketing, content strategy, and analytics",
            category: .marketing,
            icon: "megaphone.fill",
            color: Color(red: 0.9, green: 0.5, blue: 0.2),
            keywords: ["marketing", "seo", "social media", "content marketing", "google ads", "facebook ads", "analytics", "growth"],
            certificateRequirement: CertificateRequirement(minimumVideos: 280, minimumHours: 220, minimumAIScore: 70, requiredSkills: ["seo", "social media", "content strategy"]),
            skillTags: ["SEO", "Social Media", "Content Marketing", "Google Ads", "Analytics", "Email Marketing", "Growth Hacking"]
        ),
        
        // Design & UX
        CareerPath(
            id: "ui-ux-design",
            name: "UI/UX Design",
            description: "Learn user interface design, user experience, prototyping, and design systems",
            category: .design,
            icon: "paintbrush.pointed.fill",
            color: Color(red: 0.8, green: 0.2, blue: 0.5),
            keywords: ["ui design", "ux design", "figma", "sketch", "adobe xd", "prototyping", "user experience", "interface"],
            certificateRequirement: CertificateRequirement(minimumVideos: 300, minimumHours: 250, minimumAIScore: 75, requiredSkills: ["ui design", "ux principles", "prototyping"]),
            skillTags: ["UI Design", "UX Design", "Figma", "Prototyping", "Design Systems", "User Research", "Wireframing"]
        ),
        
        // Health & Wellness
        CareerPath(
            id: "personal-training",
            name: "Personal Training & Fitness",
            description: "Become a certified personal trainer, learn exercise science and nutrition",
            category: .health,
            icon: "figure.strengthtraining.traditional",
            color: Color(red: 0.9, green: 0.3, blue: 0.3),
            keywords: ["fitness", "personal trainer", "exercise", "nutrition", "workout", "strength training", "cardio"],
            certificateRequirement: CertificateRequirement(minimumVideos: 250, minimumHours: 200, minimumAIScore: 70, requiredSkills: ["exercise science", "nutrition", "program design"]),
            skillTags: ["Exercise Science", "Nutrition", "Program Design", "Client Management", "Strength Training", "Cardio"]
        ),
        
        // Skilled Trades
        CareerPath(
            id: "electrical-work",
            name: "Electrical Work",
            description: "Learn electrical systems, wiring, safety codes, and installation",
            category: .trades,
            icon: "bolt.fill",
            color: Color(red: 0.9, green: 0.7, blue: 0.1),
            keywords: ["electrical", "electrician", "wiring", "circuits", "voltage", "nec code", "residential", "commercial"],
            certificateRequirement: CertificateRequirement(minimumVideos: 280, minimumHours: 240, minimumAIScore: 80, requiredSkills: ["electrical theory", "wiring", "safety codes"]),
            skillTags: ["Electrical Theory", "Wiring", "NEC Code", "Circuit Design", "Troubleshooting", "Safety"]
        ),
        
        // Education & Teaching
        CareerPath(
            id: "online-teaching",
            name: "Online Teaching & Course Creation",
            description: "Create online courses, master teaching strategies, and build educational content",
            category: .education,
            icon: "person.2.fill",
            color: Color(red: 0.3, green: 0.5, blue: 0.9),
            keywords: ["teaching", "online courses", "education", "instructor", "curriculum", "pedagogy", "e-learning"],
            certificateRequirement: CertificateRequirement(minimumVideos: 250, minimumHours: 200, minimumAIScore: 70, requiredSkills: ["course design", "teaching methods", "content creation"]),
            skillTags: ["Course Design", "Teaching Methods", "Video Production", "Student Engagement", "Assessment"]
        ),
        
        // Science & Research
        CareerPath(
            id: "data-science",
            name: "Data Science & Analytics",
            description: "Master data analysis, machine learning, statistics, and data visualization",
            category: .science,
            icon: "chart.xyaxis.line",
            color: Color(red: 0.2, green: 0.8, blue: 0.6),
            keywords: ["data science", "machine learning", "python", "statistics", "analytics", "data analysis", "ml", "ai"],
            certificateRequirement: CertificateRequirement(minimumVideos: 350, minimumHours: 300, minimumAIScore: 80, requiredSkills: ["statistics", "python", "machine learning"]),
            skillTags: ["Python", "Statistics", "Machine Learning", "Data Visualization", "SQL", "Pandas", "Scikit-learn"]
        ),
        
        // Engineering
        CareerPath(
            id: "mechanical-engineering",
            name: "Mechanical Engineering",
            description: "Learn CAD, thermodynamics, mechanics, and engineering principles",
            category: .engineering,
            icon: "gearshape.2.fill",
            color: Color(red: 0.4, green: 0.6, blue: 0.8),
            keywords: ["mechanical engineering", "cad", "solidworks", "thermodynamics", "mechanics", "design", "manufacturing"],
            certificateRequirement: CertificateRequirement(minimumVideos: 320, minimumHours: 280, minimumAIScore: 75, requiredSkills: ["cad", "thermodynamics", "mechanics"]),
            skillTags: ["CAD", "SolidWorks", "Thermodynamics", "Mechanics", "Manufacturing", "3D Modeling"]
        ),
        
        // Legal & Compliance
        CareerPath(
            id: "paralegal",
            name: "Paralegal & Legal Studies",
            description: "Learn legal research, document preparation, and paralegal skills",
            category: .legal,
            icon: "doc.text.fill",
            color: Color(red: 0.5, green: 0.4, blue: 0.7),
            keywords: ["paralegal", "legal", "law", "legal research", "litigation", "contracts", "legal writing"],
            certificateRequirement: CertificateRequirement(minimumVideos: 280, minimumHours: 240, minimumAIScore: 75, requiredSkills: ["legal research", "legal writing", "document prep"]),
            skillTags: ["Legal Research", "Legal Writing", "Document Preparation", "Litigation", "Contracts", "Ethics"]
        )
    ]
    
    static func getCareerPath(byId id: String) -> CareerPath? {
        allCareerPaths.first { $0.id == id }
    }
    
    static func getCareerPaths(byCategory category: CareerCategory) -> [CareerPath] {
        allCareerPaths.filter { $0.category == category }
    }
}

