import Foundation

final class CacheStore {
    static let shared = CacheStore()
    private var store: [String: (data: Data, expiry: Date)] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private init() { decoder.dateDecodingStrategy = .iso8601; encoder.dateEncodingStrategy = .iso8601 }

    func set<T: Codable>(_ key: String, value: T, ttlSeconds: TimeInterval) {
        if let data = try? encoder.encode(value) {
            store[key] = (data, Date().addingTimeInterval(ttlSeconds))
        }
    }

    func get<T: Codable>(_ key: String) -> T? {
        guard let entry = store[key], entry.expiry > Date() else { return nil }
        return try? decoder.decode(T.self, from: entry.data)
    }
}


