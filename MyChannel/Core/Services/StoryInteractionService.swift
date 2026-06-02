//
//  StoryInteractionService.swift
//  MyChannel
//
//  📊 Interactive sticker backend (Instagram parity):
//  Poll votes, quiz answers, question responses, emoji-slider results,
//  countdown reminders, and link taps — all persisted to Firestore with
//  per-user dedupe and live aggregate counts.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class StoryInteractionService: ObservableObject {
    static let shared = StoryInteractionService()
    private init() {}

    /// In-memory cache of this user's interactions so the UI can show their prior
    /// choices instantly when re-opening a story.
    @Published private(set) var pollVotes: [String: String] = [:]      // pollId -> optionId
    @Published private(set) var quizAnswers: [String: Int] = [:]       // quizId -> optionIndex
    @Published private(set) var sliderResults: [String: Double] = [:]  // sliderId -> 0...1
    @Published private(set) var answeredQuestions: Set<String> = []    // questionId

    // MARK: - Poll

    /// Records a poll vote. Returns updated per-option counts keyed by optionId.
    @discardableResult
    func votePoll(storyId: String, pollId: String, optionId: String, userId: String) async -> [String: Int] {
        pollVotes[pollId] = optionId
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let pollRef = db.collection("stories").document(storyId)
            .collection("polls").document(pollId)
        let voteRef = pollRef.collection("votes").document(userId)
        do {
            // Read existing vote so we can move the count if the user changes choice.
            let existing = try? await voteRef.getDocument()
            let previousOption = existing?.data()?["optionId"] as? String

            try await voteRef.setData([
                "optionId": optionId,
                "userId": userId,
                "votedAt": FieldValue.serverTimestamp()
            ], merge: true)

            var updates: [String: Any] = ["count_\(optionId)": FieldValue.increment(Int64(1))]
            if let previousOption, previousOption != optionId {
                updates["count_\(previousOption)"] = FieldValue.increment(Int64(-1))
            }
            if previousOption == nil {
                updates["totalVotes"] = FieldValue.increment(Int64(1))
            }
            try await pollRef.setData(updates, merge: true)
            await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "poll_vote", userId: userId)
            return await pollCounts(storyId: storyId, pollId: pollId)
        } catch {
            print("🚨 [StoryInteractionService] votePoll failed: \(error.localizedDescription)")
        }
        #endif
        return [:]
    }

    func pollCounts(storyId: String, pollId: String) async -> [String: Int] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("stories").document(storyId)
                .collection("polls").document(pollId).getDocument()
            guard let data = doc.data() else { return [:] }
            var counts: [String: Int] = [:]
            for (key, value) in data where key.hasPrefix("count_") {
                let optionId = String(key.dropFirst("count_".count))
                counts[optionId] = (value as? Int) ?? 0
            }
            return counts
        } catch {
            print("🚨 [StoryInteractionService] pollCounts failed: \(error.localizedDescription)")
        }
        #endif
        return [:]
    }

    func loadMyPollVote(storyId: String, pollId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        if let doc = try? await db.collection("stories").document(storyId)
            .collection("polls").document(pollId)
            .collection("votes").document(userId).getDocument(),
           let optionId = doc.data()?["optionId"] as? String {
            pollVotes[pollId] = optionId
        }
        #endif
    }

    // MARK: - Quiz

    /// Records a quiz answer. Returns the correct option index for reveal.
    func answerQuiz(storyId: String, quizId: String, selectedIndex: Int, correctIndex: Int, userId: String) async {
        quizAnswers[quizId] = selectedIndex
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let quizRef = db.collection("stories").document(storyId)
            .collection("quizzes").document(quizId)
        do {
            try await quizRef.collection("answers").document(userId).setData([
                "selectedIndex": selectedIndex,
                "isCorrect": selectedIndex == correctIndex,
                "answeredAt": FieldValue.serverTimestamp()
            ], merge: true)
            try await quizRef.setData([
                "count_\(selectedIndex)": FieldValue.increment(Int64(1)),
                "totalAnswers": FieldValue.increment(Int64(1))
            ], merge: true)
            await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "quiz_answer", userId: userId)
        } catch {
            print("🚨 [StoryInteractionService] answerQuiz failed: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Question (open response)

    func answerQuestion(storyId: String, questionId: String, response: String, userId: String, username: String) async {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        answeredQuestions.insert(questionId)
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            try await db.collection("stories").document(storyId)
                .collection("questions").document(questionId)
                .collection("responses").addDocument(data: [
                    "userId": userId,
                    "username": username,
                    "response": trimmed,
                    "answeredAt": FieldValue.serverTimestamp()
                ])
            try await db.collection("stories").document(storyId)
                .collection("questions").document(questionId)
                .setData(["responseCount": FieldValue.increment(Int64(1))], merge: true)
            await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "question_response", userId: userId)
        } catch {
            print("🚨 [StoryInteractionService] answerQuestion failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// Fetches all open responses for a question (owner viewing results).
    func fetchQuestionResponses(storyId: String, questionId: String) async -> [(username: String, response: String)] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("stories").document(storyId)
                .collection("questions").document(questionId)
                .collection("responses")
                .order(by: "answeredAt", descending: true)
                .getDocuments()
            return snapshot.documents.map {
                (username: $0.data()["username"] as? String ?? "Someone",
                 response: $0.data()["response"] as? String ?? "")
            }
        } catch {
            print("🚨 [StoryInteractionService] fetchQuestionResponses failed: \(error.localizedDescription)")
        }
        #endif
        return []
    }

    // MARK: - Emoji slider

    /// Records an emoji-slider value (0...1). Returns the new average.
    @discardableResult
    func submitSlider(storyId: String, sliderId: String, value: Double, userId: String) async -> Double {
        let clamped = min(1, max(0, value))
        sliderResults[sliderId] = clamped
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let sliderRef = db.collection("stories").document(storyId)
            .collection("sliders").document(sliderId)
        do {
            try await sliderRef.collection("results").document(userId).setData([
                "value": clamped,
                "submittedAt": FieldValue.serverTimestamp()
            ], merge: true)
            try await sliderRef.setData([
                "sum": FieldValue.increment(clamped),
                "count": FieldValue.increment(Int64(1))
            ], merge: true)
            let doc = try await sliderRef.getDocument()
            let sum = (doc.data()?["sum"] as? Double) ?? clamped
            let count = (doc.data()?["count"] as? Int) ?? 1
            await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "slider", userId: userId)
            return count > 0 ? sum / Double(count) : clamped
        } catch {
            print("🚨 [StoryInteractionService] submitSlider failed: \(error.localizedDescription)")
        }
        #endif
        return clamped
    }

    // MARK: - Countdown reminder

    func setCountdownReminder(storyId: String, countdownId: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try? await db.collection("stories").document(storyId)
            .collection("countdowns").document(countdownId)
            .collection("reminders").document(userId).setData([
                "userId": userId,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
        await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "countdown_reminder", userId: userId)
        #endif
    }

    // MARK: - Link tap

    func trackLinkTap(storyId: String, linkURL: String, userId: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try? await db.collection("stories").document(storyId)
            .setData(["linkTapCount": FieldValue.increment(Int64(1))], merge: true)
        await StoriesIntegrationService.shared.trackStoryEngagement(storyId: storyId, action: "link_tap", userId: userId)
        #endif
    }

    /// Resets cached per-user interaction state (e.g. on sign-out).
    func reset() {
        pollVotes = [:]
        quizAnswers = [:]
        sliderResults = [:]
        answeredQuestions = []
    }
}
