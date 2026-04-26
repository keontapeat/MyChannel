//
//  QueueManagementService.swift
//  MyChannel
//
//  Upload queue, download queue, and task priority management.
//  Persistent queue, retry logic, concurrency control.
//

import Foundation

struct QueueItem: Codable, Identifiable {
    let id: String
    let type: QueueItemType
    let payload: String
    let priority: Int
    let status: QueueItemStatus
    let createdAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let retryCount: Int
    let error: String?
    enum QueueItemType: String, Codable { case upload, download, transcode, export, analyze }
    enum QueueItemStatus: String, Codable { case queued, running, completed, failed, cancelled }
}

@MainActor
final class QueueManagementService: ObservableObject {
    static let shared = QueueManagementService()
    private init() {}
    @Published private(set) var queue: [QueueItem] = []
    @Published var activeCount: Int = 0
    private let maxConcurrent = 3

    func enqueue(type: QueueItem.QueueItemType, payload: String, priority: Int = 5) -> QueueItem {
        let item = QueueItem(id: UUID().uuidString, type: type, payload: payload, priority: priority,
            status: .queued, createdAt: Date(), startedAt: nil, completedAt: nil, retryCount: 0, error: nil)
        queue.append(item)
        queue.sort { $0.priority > $1.priority }
        return item
    }

    func dequeue() -> QueueItem? {
        let running = queue.filter { $0.status == .running }.count
        guard running < maxConcurrent else { return nil }
        guard let next = queue.first(where: { $0.status == .queued }) else { return nil }
        if let idx = queue.firstIndex(where: { $0.id == next.id }) {
            queue[idx] = QueueItem(id: next.id, type: next.type, payload: next.payload, priority: next.priority,
                status: .running, createdAt: next.createdAt, startedAt: Date(), completedAt: nil, retryCount: next.retryCount, error: nil)
            activeCount += 1
        }
        return queue.first { $0.id == next.id }
    }

    func complete(itemId: String) {
        guard let idx = queue.firstIndex(where: { $0.id == itemId }) else { return }
        let old = queue[idx]
        queue[idx] = QueueItem(id: old.id, type: old.type, payload: old.payload, priority: old.priority,
            status: .completed, createdAt: old.createdAt, startedAt: old.startedAt, completedAt: Date(), retryCount: old.retryCount, error: nil)
        activeCount = max(0, activeCount - 1)
    }

    func fail(itemId: String, error: String) {
        guard let idx = queue.firstIndex(where: { $0.id == itemId }) else { return }
        let old = queue[idx]
        let newRetry = old.retryCount + 1
        let shouldRetry = newRetry < 3
        queue[idx] = QueueItem(id: old.id, type: old.type, payload: old.payload, priority: old.priority,
            status: shouldRetry ? .queued : .failed, createdAt: old.createdAt, startedAt: old.startedAt, completedAt: nil,
            retryCount: newRetry, error: shouldRetry ? nil : error)
        if !shouldRetry { activeCount = max(0, activeCount - 1) }
    }

    func cancel(itemId: String) {
        queue.removeAll { $0.id == itemId }
        activeCount = max(0, activeCount - 1)
    }

    func clearCompleted() { queue.removeAll { $0.status == .completed } }
}
