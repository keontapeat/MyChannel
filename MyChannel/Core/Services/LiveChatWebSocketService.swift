import Foundation

/// Raw WebSocket service for low-latency live stream chat using URLSessionWebSocketTask.
@MainActor
final class LiveChatWebSocketService: ObservableObject {
    static let shared = LiveChatWebSocketService()

    @Published var messages: [LiveChatMessage] = []
    @Published var isConnected = false
    @Published var viewerCount: Int = 0

    struct LiveChatMessage: Identifiable {
        let id = UUID()
        let userId: String
        let displayName: String
        let text: String
        let timestamp: Date
        let isSuperChat: Bool
        let superChatAmount: Double?
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var currentStreamId: String?
    private let baseWSURL = "wss://api.mychannel.app/live/chat"

    private init() {}

    // MARK: - Connect

    func connect(streamId: String, userId: String, authToken: String) {
        currentStreamId = streamId
        guard let url = URL(string: "\(baseWSURL)/\(streamId)?token=\(authToken)") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        webSocketTask = URLSession.configured.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        receiveLoop()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        currentStreamId = nil
    }

    // MARK: - Send

    func sendMessage(_ text: String, userId: String, displayName: String) {
        send(payload: [
            "type": "chat", "userId": userId,
            "displayName": displayName, "text": text,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    func sendSuperChat(text: String, amount: Double, userId: String, displayName: String) {
        send(payload: [
            "type": "superchat", "userId": userId,
            "displayName": displayName, "text": text,
            "amount": amount,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    private func send(payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { _ in }
    }

    // MARK: - Receive loop

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let str) = message { self.handleIncoming(str) }
                    self.receiveLoop()
                case .failure:
                    self.isConnected = false
                }
            }
        }
    }

    private func handleIncoming(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let msgType = json["type"] as? String ?? ""
        if msgType == "chat" || msgType == "superchat" {
            let msg = LiveChatMessage(
                userId: json["userId"] as? String ?? "",
                displayName: json["displayName"] as? String ?? "Anonymous",
                text: json["text"] as? String ?? "",
                timestamp: Date(),
                isSuperChat: msgType == "superchat",
                superChatAmount: json["amount"] as? Double
            )
            messages.append(msg)
            if messages.count > 500 { messages.removeFirst(100) }
        } else if msgType == "viewers" {
            viewerCount = json["count"] as? Int ?? viewerCount
        }
    }
}
