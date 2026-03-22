//
//  MusicSearchView.swift
//  MyChannel
//
//  Unified music search experience for MyChannel Music.
//

import SwiftUI

struct MusicSearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""
    @State private var selectedCategory: Category = .all
    @State private var recentSearches: [String] = []
    
    enum Category: String, CaseIterable {
        case all = "All"
        case songs = "Songs"
        case artists = "Artists"
        case albums = "Albums"
        case playlists = "Playlists"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchField
            categoryChips
            
            if query.isEmpty {
                suggestionsView
            } else {
                resultsPlaceholder
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRecent()
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            TextField("Songs, artists, albums, playlists", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Category.allCases, id: \.self) { cat in
                    Button {
                        HapticManager.shared.impact(style: .light)
                        selectedCategory = cat
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedCategory == cat ? .white : AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == cat ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Searches")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        ForEach(recentSearches, id: \.self) { term in
                            Button {
                                query = term
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    Text(term)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Browse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    let chips = ["Hip-Hop", "R&B", "Michigan Rap", "Detroit", "Trap", "Workout", "Chill", "Party"]
                    WrapChipsView(items: chips) { label in
                        Button {
                            query = label
                        } label: {
                            Text(label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.Colors.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var resultsPlaceholder: some View {
        List {
            Section("Top Results") {
                Text("Search results for \"\(query)\"")
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func loadRecent() {
        if let stored = UserDefaults.standard.array(forKey: "music_recent_searches") as? [String] {
            recentSearches = stored
        }
    }
}

// MARK: - Simple wrap layout for chips

private struct WrapChipsView<Content: View>: View {
    let items: [String]
    let content: (String) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            var width: CGFloat = 0
            var height: CGFloat = 0
            
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(items, id: \.self) { item in
                        content(item)
                            .padding(.trailing, 8)
                            .alignmentGuide(.leading) { dimension in
                                if (width + dimension.width) > geometry.size.width {
                                    width = 0
                                    height -= dimension.height + 8
                                }
                                let result = width
                                if item == items.last {
                                    width = 0
                                } else {
                                    width += dimension.width + 8
                                }
                                return result
                            }
                            .alignmentGuide(.top) { _ in
                                let result = height
                                if item == items.last {
                                    height = 0
                                }
                                return result
                            }
                    }
                }
            }
            .frame(minHeight: 40)
        }
    }
}

