// NotificationEngineV2.swift - 🔔 SMART NOTIFICATIONS!
import Foundation
@MainActor
class NotificationEngineV2: ObservableObject {
    static let shared = NotificationEngineV2()
    @Published var sent: Int = 0
    func sendSmart(_ message: String, to userId: String) async {
        print("🔔 [Notify] Sending...")
        sent += 1
    }
}
