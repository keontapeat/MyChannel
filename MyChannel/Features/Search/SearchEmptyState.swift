//
//  SearchEmptyState.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI

// 🔥 YouTube-Parity Search Empty State
// Shows trending searches, recent searches, and search history management
struct SearchEmptyState: View {
    let recentSearches: [String]
    let onSearchTap: (String) -> Void
    
    @StateObject private var historyService = SearchHistoryService.shared
    @StateObject private var trendingService = TrendingSearchService.shared
    @State private var showingHistorySettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search History Section
                if historyService.isEnabled && !historyService.searchHistory.isEmpty {
                    SearchHistorySection(
                        history: historyService.searchHistory,
                        onSearchTap: onSearchTap,
                        onRemove: { item in
                            HapticManager.shared.impact(style: .light)
                            historyService.removeSearch(item)
                        },
                        onClearAll: {
                            HapticManager.shared.impact(style: .medium)
                            showingHistorySettings = true
                        }
                    )
                }
                
                // Trending Searches Section
                if !trendingService.trendingSearches.isEmpty {
                    TrendingSearchesSection(
                        trending: trendingService.trendingSearches,
                        onSearchTap: onSearchTap
                    )
                }
                
                // Search Tips Section
                SearchTipsSection()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(AppTheme.Colors.background)
        .actionSheet(isPresented: $showingHistorySettings) {
            ActionSheet(
                title: Text("Search History"),
                message: Text("Manage your search history settings"),
                buttons: [
                    .destructive(Text("Clear All History")) {
                        historyService.clearAllHistory()
                    },
                    .default(Text("Turn Off History")) {
                        historyService.toggleHistoryEnabled()
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Search History Section
private struct SearchHistorySection: View {
    let history: [SearchHistoryItem]
    let onSearchTap: (String) -> Void
    let onRemove: (SearchHistoryItem) -> Void
    let onClearAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("Clear All") {
                    onClearAll()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(history.prefix(10)) { item in
                    SearchHistoryRow(
                        item: item,
                        onTap: { onSearchTap(item.query) },
                        onRemove: { onRemove(item) }
                    )
                }
            }
        }
    }
}

// MARK: - Search History Row
private struct SearchHistoryRow: View {
    let item: SearchHistoryItem
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.query)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 8) {
                            Text(item.scope.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(item.timeAgo)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
}

// MARK: - Trending Searches Section
private struct TrendingSearchesSection: View {
    let trending: [TrendingSearch]
    let onSearchTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Trending")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(trending.prefix(8)) { trend in
                    TrendingSearchRow(
                        trend: trend,
                        onTap: { onSearchTap(trend.term) }
                    )
                }
            }
        }
    }
}

// MARK: - Trending Search Row
private struct TrendingSearchRow: View {
    let trend: TrendingSearch
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(trend.term)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Text("\(trend.searchCount) searches")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if let category = trend.category {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(category)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Trend indicator
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text(String(format: "%.1f", trend.trendScore))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Tips Section
private struct SearchTipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Tips")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                SearchTip(
                    icon: "quote.bubble",
                    title: "Exact phrases",
                    description: "Use quotes for exact matches",
                    example: "\"iPhone review\""
                )
                
                SearchTip(
                    icon: "minus.circle",
                    title: "Exclude words",
                    description: "Use minus to exclude terms",
                    example: "iPhone -case"
                )
                
                SearchTip(
                    icon: "at",
                    title: "Search channels",
                    description: "Find content from specific creators",
                    example: "@mkbhd"
                )
                
                SearchTip(
                    icon: "number",
                    title: "Search hashtags",
                    description: "Find content by hashtag",
                    example: "#technology"
                )
            }
        }
    }
}

// MARK: - Search Tip
private struct SearchTip: View {
    let icon: String
    let title: String
    let description: String
    let example: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(example)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.surface)
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.background)
        .cornerRadius(AppTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

#Preview {
    SearchEmptyState(recentSearches: ["iPhone", "SwiftUI", "iOS 17"]) { search in
        print("Search: \(search)")
    }
}
