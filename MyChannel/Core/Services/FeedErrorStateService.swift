//
//  FeedErrorStateService.swift
//  MyChannel
//
//  Phase 265: Feed Error & Empty States — contextual error messages,
//  retry strategies, offline fallback, empty state illustrations, diagnostics.
//

import Foundation

struct FeedErrorState: Codable, Identifiable {
    let id: String
    let type: ErrorType
    let title: String
    let message: String
    let retryable: Bool
    let retryCount: Int
    let maxRetries: Int
    let illustration: String
    enum ErrorType: String, Codable { case network, server, empty, rateLimit, auth, unknown }
}

@MainActor
final class FeedErrorStateService: ObservableObject {
    static let shared = FeedErrorStateService()
    private init() {}
    @Published private(set) var currentError: FeedErrorState?
    private var retryDelays: [TimeInterval] = [1, 2, 5, 10, 30]

    func handleError(_ error: Error) -> FeedErrorState {
        let nsErr = error as NSError
        let state: FeedErrorState
        if nsErr.code == NSURLErrorNotConnectedToInternet || nsErr.code == NSURLErrorTimedOut {
            state = FeedErrorState(id: UUID().uuidString, type: .network, title: "No Connection", message: "Check your internet and try again",
                retryable: true, retryCount: 0, maxRetries: 5, illustration: "wifi.slash")
        } else if nsErr.code >= 500 {
            state = FeedErrorState(id: UUID().uuidString, type: .server, title: "Server Error", message: "We're working on it. Try again shortly.",
                retryable: true, retryCount: 0, maxRetries: 3, illustration: "exclamationmark.icloud")
        } else if nsErr.code == 429 {
            state = FeedErrorState(id: UUID().uuidString, type: .rateLimit, title: "Slow Down", message: "Too many requests. Wait a moment.",
                retryable: true, retryCount: 0, maxRetries: 2, illustration: "tortoise")
        } else {
            state = FeedErrorState(id: UUID().uuidString, type: .unknown, title: "Something Went Wrong", message: error.localizedDescription,
                retryable: true, retryCount: 0, maxRetries: 3, illustration: "questionmark.circle")
        }
        currentError = state; return state
    }

    func emptyState(for section: String) -> FeedErrorState {
        FeedErrorState(id: "empty_\(section)", type: .empty, title: "Nothing Here Yet",
            message: section == "subscriptions" ? "Subscribe to creators to see their content here" : "Check back soon for new content",
            retryable: false, retryCount: 0, maxRetries: 0, illustration: "tray")
    }

    func retryDelay(for retryCount: Int) -> TimeInterval {
        retryCount < retryDelays.count ? retryDelays[retryCount] : retryDelays.last ?? 30
    }

    func clearError() { currentError = nil }
}
