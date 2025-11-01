import Foundation

struct DeviceSession: Identifiable, Codable, Equatable {
    let id: String
    let deviceName: String
    let platform: String
    let lastActive: Date
    let ipAddress: String?
    let isCurrent: Bool
}



