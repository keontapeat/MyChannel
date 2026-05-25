import Foundation

// Persisted owner-configurable list of FriendArtist used for Music/Top Artists
@MainActor
final class OwnerFriendsStore: ObservableObject {
    static let shared = OwnerFriendsStore()
    private init() { load() }

    @Published private(set) var friends: [FriendArtist] = []
    private let key = "owner_dynamic_friends_v1"

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { friends = []; return }
        if let decoded = try? JSONDecoder().decode([FriendArtist].self, from: data) {
            friends = decoded
        } else {
            friends = []
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func set(_ list: [FriendArtist]) {
        friends = list
        persist()
    }

    func append(_ item: FriendArtist) {
        if !friends.contains(where: { $0.name == item.name }) {
            friends.append(item)
            persist()
        }
    }

    // Input format (one per line, commas or pipes accepted):
    //   @handle
    //   Display Name,@handle
    //   Display Name|@handle|https://custom-avatar.jpg
    func importFromString(_ text: String) {
        let separators = CharacterSet(charactersIn: "\n,|")
        let lines = text
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [FriendArtist] = friends
        for raw in lines {
            let parts = raw
                .components(separatedBy: ["|", ","]) // split by '|' or ','
                .map { $0.trimmingCharacters(in: .whitespaces) }
            var display = raw
            var handle = raw
            var avatar: String? = nil
            if parts.count == 1 {
                display = raw
                handle = raw
            } else if parts.count == 2 {
                display = parts[0]
                handle = parts[1]
            } else if parts.count >= 3 {
                display = parts[0]
                handle = parts[1]
                avatar = parts[2]
            }

            if !handle.starts(with: "@") { handle = "@" + handle }
            let handleOnly = handle.replacingOccurrences(of: "@", with: "")
            let resolvedAvatar = avatar ?? "https://unavatar.io/instagram/\(handleOnly)"
            let item = FriendArtist(name: display, instagram: handle, avatar: resolvedAvatar)
            if !result.contains(where: { $0.name == item.name }) {
                result.append(item)
            }
        }
        friends = result
        persist()
    }
}


