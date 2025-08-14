import SwiftUI

struct OwnerProfile {
    static let instagramUsername = "sbkeonta_"
    static let instagramURL = "https://www.instagram.com/sbkeonta_/?next=%2F"
    static let youtubeURL = "https://www.youtube.com/watch?v=71GJrAY54Ew&list=RD71GJrAY54Ew&start_radio=1"

    static var user: User {
        User(
            id: "owner_keonta",
            username: instagramUsername,
            displayName: "Keonta",
            email: "owner@mychannel.app",
            profileImageURL: "https://i.pravatar.cc/200?u=\(instagramUsername)",
            bannerImageURL: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1600&q=80",
            bio: "Detroit | Creator • Follow IG: @\(instagramUsername)\nMusic: \(youtubeURL)",
            subscriberCount: 25400,
            videoCount: 156,
            isVerified: true,
            isCreator: true,
            socialLinks: [
                SocialLink(platform: .instagram, url: instagramURL, displayName: "@\(instagramUsername)"),
                SocialLink(platform: .youtube, url: youtubeURL, displayName: "Latest Track")
            ],
            followingCount: 150
        )
    }
}

#Preview("OwnerProfile User") {
    VStack(spacing: 12) {
        ProfileAvatarView(urlString: OwnerProfile.user.profileImageURL, size: 64, showsRing: true)
        Text(OwnerProfile.user.displayName).font(.headline)
        Text("@\(OwnerProfile.user.username)").foregroundStyle(.secondary)
        Text(OwnerProfile.user.bio ?? "").font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    .padding()
}