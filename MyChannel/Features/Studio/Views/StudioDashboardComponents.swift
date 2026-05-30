// ⚡ PERFORMANCE: Extracted from NuclearYouTubeStudioDashboard.swift — independent compilation unit.
// Data types, stat items, comment rows, idea rows all compile in parallel.
import SwiftUI

// MARK: - Supporting Types
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

struct StudioDashboardComment: Identifiable {
    let id: String
    let username: String
    let text: String
    let videoTitle: String
    let avatarURL: String
    let timestamp: Date
}

struct RecentSubscriber: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String
    let subscribedAt: Date
}

struct ContentIdea: Identifiable {
    let id: String
    let title: String
    let description: String
    let trendScore: Double
}

struct CreatorNews: Identifiable {
    let id: String
    let title: String
    let description: String
    let date: Date
    let imageURL: String?
}

// MARK: - Supporting Views
struct AnalyticsStatItem: View {
    let title: String
    let value: String
    let change: Double
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.1f%%", abs(change)))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VideoStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

struct StudioCommentRow: View {
    let comment: StudioDashboardComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(comment.username.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(timeAgo(from: comment.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("on \(comment.videoTitle)")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "heart")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}

struct IdeaRow: View {
    let idea: ContentIdea
    
    var body: some View {
        HStack(spacing: 12) {
            // Trend indicator
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(idea.description)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Trend score
            Text("\(Int(idea.trendScore * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
    }
}

struct NewsRow: View {
    let news: CreatorNews
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(news.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(news.description)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(formatDate(news.date))
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Placeholder Views
struct StudioNotificationsView: View {
    var body: some View {
        Text("Notifications")
            .navigationTitle("Notifications")
    }
}

struct StudioCommentsView: View {
    var body: some View {
        Text("All Comments")
            .navigationTitle("Comments")
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        NuclearYouTubeStudioDashboard()
            .environmentObject(AppState.shared)
    }
}






