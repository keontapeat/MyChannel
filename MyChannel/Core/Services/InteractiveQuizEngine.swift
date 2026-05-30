import Foundation
import Combine
import FirebaseFirestore
import AVFoundation

struct VideoQuiz: Codable, Identifiable {
    @DocumentID var id: String?
    let timestamp: Double // When the quiz appears in the video
    let question: String
    let options: [String]
    let correctOptionIndex: Int
}

/// Phase 75: Interactive Video Quizzes
/// Pauses the video at specific timestamps and presents Firestore-validated quizzes.
@MainActor
final class InteractiveQuizEngine: ObservableObject {
    static let shared = InteractiveQuizEngine()
    private let db = Firestore.firestore()
    
    @Published var activeQuizzes: [VideoQuiz] = []
    @Published var currentQuizToDisplay: VideoQuiz?
    
    private var timeObserver: Any?
    private weak var currentItem: AVPlayerItem?
    private weak var player: AVPlayer?
    
    private var lastCheckedTime: Double = -1
    
    private init() {}
    
    /// Loads quizzes for a specific video from Firestore
    func loadQuizzes(for videoId: String) {
        db.collection("videos").document(videoId).collection("quizzes").getDocuments { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents else { return }
            
            self.activeQuizzes = docs.compactMap { doc in
                try? doc.data(as: VideoQuiz.self)
            }
            print("📝 [QuizEngine] Loaded \(self.activeQuizzes.count) quizzes for video \(videoId).")
        }
    }
    
    /// Attaches to the AVPlayer to monitor time and present quizzes
    func attach(to player: AVPlayer) {
        self.player = player
        self.currentItem = player.currentItem
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.checkTime(time.seconds)
        }
    }
    
    func detach() {
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
            timeObserver = nil
        }
        player = nil
        currentItem = nil
        activeQuizzes.removeAll()
        currentQuizToDisplay = nil
    }
    
    private func checkTime(_ currentTime: Double) {
        // Round to nearest 0.5s to match interval
        let roundedTime = (currentTime * 2).rounded() / 2.0
        guard roundedTime != lastCheckedTime else { return }
        lastCheckedTime = roundedTime
        
        // Find if a quiz is scheduled exactly at this timestamp
        if let quiz = activeQuizzes.first(where: { abs($0.timestamp - roundedTime) < 0.5 }) {
            // We found a quiz! Pause the video and display it
            player?.pause()
            self.currentQuizToDisplay = quiz
            print("🛑 [QuizEngine] Video paused for quiz: '\(quiz.question)'")
            
            // Remove it so it doesn't trigger again on seeking back
            activeQuizzes.removeAll(where: { $0.id == quiz.id })
        }
    }
    
    func submitAnswer(optionIndex: Int) -> Bool {
        guard let quiz = currentQuizToDisplay else { return false }
        
        let isCorrect = optionIndex == quiz.correctOptionIndex
        print(isCorrect ? "✅ [QuizEngine] Correct answer!" : "❌ [QuizEngine] Wrong answer.")
        
        // Resume video
        self.currentQuizToDisplay = nil
        player?.play()
        
        return isCorrect
    }
}
