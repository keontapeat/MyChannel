import SwiftUI

// MARK: - Profile Community View
struct ProfileCommunityView: View {
    let user: User
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<5) { index in
                ProfileCommunityPost(
                    author: user,
                    content: "This is a sample community post \(index + 1). Thanks for following my channel!",
                    timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                    likeCount: Int.random(in: 10...500),
                    commentCount: Int.random(in: 2...50)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Community Post
struct ProfileCommunityPost: View {
    let author: User
    let content: String
    let timestamp: Date
    let likeCount: Int
    let commentCount: Int
    
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.7))
                        .overlay(
                            Text(String(author.displayName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(author.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        if author.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    
                    Text(timeAgoString(from: timestamp))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            
            // Content
            Text(content)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isLiked.toggle()
                    }
                    HapticManager.shared.impact(style: .light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundStyle(isLiked ? .red : AppTheme.Colors.textSecondary)
                        
                        Text("\(likeCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        
                        Text("\(commentCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
