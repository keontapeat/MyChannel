//
//  RankCardView.swift
//  MyChannel
//
//  Reusable rank card for Top Artists, Top Filmmakers, Top MyChannels.
//  Shows avatar, rank badge with rank-change indicator, and subtitle.
//

import SwiftUI

struct RankCardView: View {
    let user: TopRankedUser
    var subtitle: String? = nil

    // Displayed rank is the engine-assigned `user.rank` (single source of truth),
    // so the "#" badge always matches the rank-change arrow and the See All list.
    private var displayRank: Int { max(user.rank, 1) }

    private var displayName: String {
        user.name
            .replacingOccurrences(of: "_c", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displaySubtitle: String {
        if let s = subtitle { return s }
        return "\(TopRankMLService.formatCount(user.totalViews)) total views"
    }

    private var rankBadgeColor: Color {
        switch displayRank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // bronze
        default: return AppTheme.Colors.primary
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .topLeading) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.primary, lineWidth: 3)
                        .frame(width: 64, height: 64)

                    // Avatar with asset:// support
                    if user.avatar.hasPrefix("asset://") {
                        let assetName = String(user.avatar.dropFirst(8))
                        if let img = UIImage(named: assetName) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                        } else {
                            placeholderCircle
                        }
                    } else {
                        AppAsyncImage(url: URL(string: user.avatar)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { placeholderCircle }
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                    }
                }

                // Rank badge
                Text("#\(displayRank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(rankBadgeColor))
                    .offset(x: -2, y: -2)
            }

            VStack(alignment: .center, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 110)

                Text(displaySubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 110)
            }
        }
        .frame(width: 120)
    }

    private var placeholderCircle: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.secondary)
                .padding(12)
        }
        .frame(width: 58, height: 58)
    }
}
