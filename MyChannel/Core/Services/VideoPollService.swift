//
//  VideoPollService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI
import Combine

// MARK: - Video Poll Service Protocol
protocol VideoPollServiceProtocol {
    func getPolls(for videoId: String) async throws -> [VideoPoll]
    func createPoll(_ poll: VideoPoll) async throws -> VideoPoll
    func updatePoll(_ poll: VideoPoll) async throws -> VideoPoll
    func deletePoll(id: String) async throws
    func vote(pollId: String, optionId: String) async throws -> VideoPoll
}

// MARK: - Video Poll Service
@MainActor
class VideoPollService: ObservableObject, VideoPollServiceProtocol {
    static let shared = VideoPollService()
    
    @Published var polls: [String: [VideoPoll]] = [:] // videoId -> polls
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        for poll in VideoPoll.samplePolls {
            if polls[poll.videoId] == nil {
                polls[poll.videoId] = []
            }
            polls[poll.videoId]?.append(poll)
        }
    }
    
    // MARK: - Public Methods
    func getPolls(for videoId: String) async throws -> [VideoPoll] {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return polls[videoId]?.sorted(by: { $0.timestamp < $1.timestamp }) ?? []
    }
    
    func createPoll(_ poll: VideoPoll) async throws -> VideoPoll {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        if polls[poll.videoId] == nil {
            polls[poll.videoId] = []
        }
        polls[poll.videoId]?.append(poll)
        
        return poll
    }
    
    func updatePoll(_ poll: VideoPoll) async throws -> VideoPoll {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard var videoPolls = polls[poll.videoId],
              let index = videoPolls.firstIndex(where: { $0.id == poll.id }) else {
            throw VideoPollError.pollNotFound
        }
        
        videoPolls[index] = poll
        polls[poll.videoId] = videoPolls
        
        return poll
    }
    
    func deletePoll(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        for (videoId, videoPolls) in polls {
            if videoPolls.contains(where: { $0.id == id }) {
                polls[videoId] = videoPolls.filter { $0.id != id }
                return
            }
        }
        
        throw VideoPollError.pollNotFound
    }
    
    func vote(pollId: String, optionId: String) async throws -> VideoPoll {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        for (videoId, var videoPolls) in polls {
            if let index = videoPolls.firstIndex(where: { $0.id == pollId }) {
                var poll = videoPolls[index]
                poll.vote(for: optionId)
                videoPolls[index] = poll
                polls[videoId] = videoPolls
                return poll
            }
        }
        
        throw VideoPollError.pollNotFound
    }
    
    // MARK: - Helper Methods
    func getPollAtTimestamp(_ timestamp: TimeInterval, for videoId: String) -> VideoPoll? {
        guard let videoPolls = polls[videoId] else { return nil }
        
        return videoPolls.first { poll in
            timestamp >= poll.timestamp &&
            (poll.displayDuration == 0 || timestamp <= poll.timestamp + poll.displayDuration)
        }
    }
}

// MARK: - Video Poll Error
enum VideoPollError: LocalizedError {
    case pollNotFound
    case pollEnded
    case alreadyVoted
    case invalidOption
    
    var errorDescription: String? {
        switch self {
        case .pollNotFound: return "Poll not found"
        case .pollEnded: return "This poll has ended"
        case .alreadyVoted: return "You have already voted"
        case .invalidOption: return "Invalid poll option"
        }
    }
}

// MARK: - Poll Playback Manager
@MainActor
class PollPlaybackManager: ObservableObject {
    @Published var currentPoll: VideoPoll?
    @Published var showPoll = false
    @Published var hasVoted = false
    @Published var showResults = false
    @Published var dismissedPollIds: Set<String> = []
    
    private let service: VideoPollService
    private var allPolls: [VideoPoll] = []
    private var currentVideoId: String?
    
    init(service: VideoPollService = .shared) {
        self.service = service
    }
    
    func loadPolls(for videoId: String) async {
        currentVideoId = videoId
        dismissedPollIds.removeAll()
        currentPoll = nil
        showPoll = false
        
        do {
            allPolls = try await service.getPolls(for: videoId)
        } catch {
            print("Failed to load polls: \(error)")
            allPolls = []
        }
    }
    
    func updatePlaybackTime(_ time: TimeInterval) {
        // Find poll that should be shown at this time
        if let poll = allPolls.first(where: { poll in
            !dismissedPollIds.contains(poll.id) &&
            time >= poll.timestamp &&
            (poll.displayDuration == 0 || time <= poll.timestamp + poll.displayDuration)
        }) {
            if currentPoll?.id != poll.id {
                currentPoll = poll
                hasVoted = poll.hasUserVoted
                showResults = poll.hasUserVoted || poll.showResultsBeforeVoting
                showPoll = true
            }
        } else if let currentPoll = currentPoll,
                  currentPoll.displayDuration > 0,
                  time > currentPoll.timestamp + currentPoll.displayDuration {
            // Auto-dismiss poll after duration
            dismissPoll()
        }
    }
    
    func vote(for optionId: String) async {
        guard let poll = currentPoll else { return }
        
        do {
            let updatedPoll = try await service.vote(pollId: poll.id, optionId: optionId)
            currentPoll = updatedPoll
            hasVoted = true
            showResults = true
            
            // Update in allPolls
            if let index = allPolls.firstIndex(where: { $0.id == poll.id }) {
                allPolls[index] = updatedPoll
            }
        } catch {
            print("Failed to vote: \(error)")
        }
    }
    
    func dismissPoll() {
        if let poll = currentPoll {
            dismissedPollIds.insert(poll.id)
        }
        showPoll = false
        currentPoll = nil
    }
    
    func resetDismissedPolls() {
        dismissedPollIds.removeAll()
    }
}
