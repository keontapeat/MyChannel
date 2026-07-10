//
//  PosterURLValidator.swift
//  MyChannel
//
//  Validates movie poster URLs against image URL standards (no wikipedia/wikimedia/svg).
//

import Foundation

enum PosterURLValidator {
    private static let blockedHosts = ["wikipedia.org", "wikimedia.org"]
    private static let approvedHosts = [
        "ytimg.com", "imgur.com", "cloudinary.com", "googleusercontent.com",
        "akamaized.net", "cloudfront.net", "pluto.tv", "image.tmdb.org", "m.media-amazon.com"
    ]

    /// Returns true when the URL is safe for AsyncImage movie posters.
    static func isAllowed(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              !urlString.lowercased().hasSuffix(".svg") else {
            return false
        }
        if blockedHosts.contains(where: { host.contains($0) }) { return false }
        if approvedHosts.contains(where: { host.contains($0) }) { return true }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "gif"].contains(ext)
    }
}
