//
//  SearchFiltersView.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI

// 🔥 YouTube-Parity Search Filters
// Matches YouTube's filter system exactly
struct SearchFiltersView: View {
    @Binding var filters: MyChannel.SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Upload Date Filter
                    FilterSection(title: "Upload Date") {
                        VStack(spacing: 12) {
                            ForEach([nil] + MyChannel.SearchFilters.UploadDateFilter.allCases, id: \.self) { dateFilter in
                                FilterOption(
                                    title: dateFilter?.rawValue ?? "Any time",
                                    isSelected: filters.uploadDate == dateFilter,
                                    action: {
                                        HapticManager.shared.impact(style: .light)
                                        filters.uploadDate = dateFilter
                                    }
                                )
                            }
                        }
                    }
                    
                    // Type Filter
                    FilterSection(title: "Type") {
                        VStack(spacing: 12) {
                            FilterOption(
                                title: "Any",
                                isSelected: filters.contentType == nil,
                                action: {
                                    HapticManager.shared.impact(style: .light)
                                    filters.contentType = nil
                                }
                            )
                            
                            ForEach(MyChannel.SearchFilters.ContentType.allCases, id: \.self) { contentType in
                                FilterOption(
                                    title: contentType.rawValue,
                                    isSelected: filters.contentType == contentType,
                                    action: {
                                        HapticManager.shared.impact(style: .light)
                                        filters.contentType = contentType
                                    }
                                )
                            }
                        }
                    }
                    
                    // Duration Filter
                    FilterSection(title: "Duration") {
                        VStack(spacing: 12) {
                            ForEach([nil] + MyChannel.SearchFilters.DurationFilter.allCases, id: \.self) { duration in
                                FilterOption(
                                    title: duration?.rawValue ?? "Any",
                                    isSelected: filters.duration == duration,
                                    action: {
                                        HapticManager.shared.impact(style: .light)
                                        filters.duration = duration
                                    }
                                )
                            }
                        }
                    }
                    
                    // Features Filter
                    FilterSection(title: "Features") {
                        VStack(spacing: 12) {
                            ForEach(MyChannel.SearchFilters.FeatureFilter.allCases, id: \.self) { feature in
                                FilterOption(
                                    title: feature.rawValue,
                                    isSelected: filters.features.contains(feature),
                                    action: {
                                        HapticManager.shared.impact(style: .light)
                                        if filters.features.contains(feature) {
                                            filters.features.remove(feature)
                                        } else {
                                            filters.features.insert(feature)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // Sort By Filter
                    FilterSection(title: "Sort by") {
                        VStack(spacing: 12) {
                            ForEach(MyChannel.SearchFilters.SortOption.allCases, id: \.self) { sortOption in
                                FilterOption(
                                    title: sortOption.rawValue,
                                    isSelected: filters.sortBy == sortOption,
                                    action: {
                                        HapticManager.shared.impact(style: .light)
                                        filters.sortBy = sortOption
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Space for buttons
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        HapticManager.shared.impact(style: .medium)
                        filters = SearchFilters()
                        onApply()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(style: .light)
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Filter Section
private struct FilterSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filter Option
private struct FilterOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SearchFiltersView(filters: .constant(MyChannel.SearchFilters())) {
        print("Filters applied")
    }
}
