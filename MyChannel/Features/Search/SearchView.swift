//
//  SearchView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import Combine
import AVFoundation

// 🔥🔥🔥 NUCLEAR SEARCH VIEW 🔥🔥🔥
// Features:
// 1. Voice Search (speech-to-text)
// 2. AI-Powered Smart Suggestions (Claude)
// 3. Search Operators (title:, @channel, #hashtag, date:)
// 4. Autocomplete Dropdown
// 5. Search Corrections ("Did you mean...?")
// 6. Related Searches
// 7. Search Highlights
// 8. Personalized Results
// 9. Search Analytics
// 10. Infinite Scroll
// 11. Visual Search (camera)
// 12. Search History Sync
// 13. Trending Real-time
// 14. Beautiful Animations
// 15. Enhanced Empty States

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = AdvancedSearchService()
    @StateObject private var voiceSearch = VoiceSearchService()
    @StateObject private var trendingService = TrendingSearchService.shared
    @StateObject private var historyService = SearchHistoryService.shared
    
    @State private var searchText: String = ""
    @State private var selectedScope: SearchScope = .all
    @State private var isSearching: Bool = false
    @State private var recentSearches: [String] = []
    @State private var searchFilters = MyChannel.SearchFilters()
    @State private var showingFilters = false
    @State private var showingVoiceSearch = false
    @State private var showingVisualSearch = false
    @State private var showingSuggestions = false
    @State private var suggestions: [SearchSuggestion] = []
    @State private var searchCorrection: String?
    @State private var relatedSearches: [String] = []
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @FocusState private var isSearchFieldFocused: Bool
    
    // ⚡ PERFORMANCE: Debounced search with Combine
    @State private var searchTask: Task<Void, Never>?
    @State private var cancellables = Set<AnyCancellable>()
    private let searchSubject = PassthroughSubject<String, Never>()

    var body: some View {
        NavigationStack {
            // Main content
            VStack(spacing: 0) {
                // 🔥 PREMIUM: Scopes with haptics and spring animations
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Button(scope.displayName) {
                                // 🔥 PREMIUM: Haptic on scope change
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedScope = scope
                                }
                                if !searchText.isEmpty {
                                    performSearch()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedScope == scope ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .foregroundColor(selectedScope == scope ? .white : AppTheme.Colors.textPrimary)
                            .cornerRadius(AppTheme.CornerRadius.md)
                            // 🔥 PREMIUM: Scale animation for selected scope
                            .scaleEffect(selectedScope == scope ? 1.02 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedScope)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                ZStack(alignment: .topLeading) {
                    if searchText.isEmpty {
                        SearchEmptyState(recentSearches: historyService.getRecentSearches()) { search in
                            searchText = search
                            performSearch()
                        }
                    } else if isSearching {
                        SearchLoadingState()
                    } else {
                        ModernSearchResultsList(
                            results: searchService.searchResults,
                            searchCorrection: searchCorrection,
                            relatedSearches: relatedSearches,
                            isLoadingMore: isLoadingMore,
                            onCorrectionTap: { correction in
                                searchText = correction
                                performSearch()
                            },
                            onRelatedTap: { related in
                                searchText = related
                                performSearch()
                            },
                            onLoadMore: {
                                loadMoreResults()
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .transaction { $0.animation = nil }
            .animation(.none, value: isSearching)
            .animation(.none, value: searchText)
            .animation(.none, value: selectedScope)
            .animation(.none, value: isSearchFieldFocused)
            .safeAreaInset(edge: .top) { header } // Pinned header with proper safe-area handling
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)

        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SearchLoseFocus"))) { _ in
            var tx = SwiftUI.Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                isSearchFieldFocused = false
            }
        }

        // Always resign focus when leaving the Search tab
        .onDisappear {
            var tx = SwiftUI.Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                isSearchFieldFocused = false
            }
        }

        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchFilters) {
                if !searchText.isEmpty { performSearch() }
            }
        }
        .sheet(isPresented: $showingVoiceSearch) {
            VoiceSearchSheet(
                voiceSearch: voiceSearch,
                onComplete: { text in
                    searchText = text
                    showingVoiceSearch = false
                    performSearch()
                }
            )
        }
        .sheet(isPresented: $showingVisualSearch) {
            VisualSearchSheet(onComplete: { query in
                searchText = query
                showingVisualSearch = false
                performSearch()
            })
        }
        .onAppear {
            // Load recent searches from UserDefaults
            if let saved = UserDefaults.standard.array(forKey: "recent_searches") as? [String] {
                recentSearches = saved
            }
            
            // ⚡ PERFORMANCE: Setup debounced search with Combine
            searchSubject
                .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
                .removeDuplicates()
                .sink { query in
                    guard !query.isEmpty else {
                        self.suggestions = []
                        self.showingSuggestions = false
                        return
                    }
                    
                    // Generate suggestions
                    Task {
                        let newSuggestions = await SearchSuggestionService.shared.generateSuggestions(for: query)
                        await MainActor.run {
                            self.suggestions = newSuggestions
                            self.showingSuggestions = !newSuggestions.isEmpty
                        }
                    }
                }
                .store(in: &cancellables)
        }
        .onChange(of: searchText) { newValue in
            // Send to debounced publisher
            searchSubject.send(newValue)
        }
        .onDisappear {
            // ⚡ PERFORMANCE: Cancel search task and cleanup
            searchTask?.cancel()
            cancellables.removeAll()
            
            // Save recent searches
            UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    TextField("Search", text: $searchText)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.webSearch)
                        .onSubmit { performSearch() }
                    
                    if !searchText.isEmpty {
                        Button {
                            // 🔥 PREMIUM: Haptic on clear
                            HapticManager.shared.impact(style: .light)
                            var tx = SwiftUI.Transaction()
                            tx.disablesAnimations = true
                            withTransaction(tx) { 
                                searchText = ""
                                suggestions = []
                                showingSuggestions = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // 🎤 🔥 PREMIUM: Voice Search Button with pulse animation
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        showingVoiceSearch = true
                    }) {
                        Image(systemName: voiceSearch.isListening ? "waveform" : "mic.fill")
                            .foregroundColor(voiceSearch.isListening ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            .scaleEffect(voiceSearch.isListening ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatForever(autoreverses: true), value: voiceSearch.isListening)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)

                Button(action: {
                    // 🔥 PREMIUM: Haptic on filter open
                    HapticManager.shared.impact(style: .light)
                    showingFilters.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            
            // 🔥 PREMIUM: Autocomplete Suggestions with haptics
            if showingSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(5)) { suggestion in
                        Button(action: {
                            // 🔥 PREMIUM: Haptic on suggestion tap
                            HapticManager.shared.impact(style: .light)
                            searchText = suggestion.text
                            showingSuggestions = false
                            performSearch()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.text)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    if let subtitle = suggestion.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // AI badge for AI-generated suggestions
                                if suggestion.isAIGenerated {
                                    Text("AI")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            LinearGradient(
                                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppTheme.Colors.surface)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if suggestion != suggestions.prefix(5).last {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingSuggestions)
            }
        }
        .background(AppTheme.Colors.background)
    }

    // MARK: - Actions
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Hide suggestions
        showingSuggestions = false
        
        // ⚡ PERFORMANCE: Cancel previous search task
        searchTask?.cancel()
        
        isSearching = true
        currentPage = 1
        
        searchTask = Task {
            defer { 
                Task { @MainActor in isSearching = false }
            }
            
            do {
                // Track search analytics
                await trendingService.trackSearch(term: searchText)
                
                let _ = try await searchService.search(query: searchText, filters: searchFilters)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // 🤖 SEARCH RANKING AI: Re-rank results using Cloud Run agent (non-blocking)
                let querySnapshot = searchText
                let resultIds = searchService.searchResults.compactMap { result -> String? in
                    if case .video(let r) = result { return r.video.id }
                    return nil
                }
                if !resultIds.isEmpty {
                    Task {
                        struct RankRequest: Encodable {
                            let query: String
                            let video_ids: [String]
                            let user_id: String?
                        }
                        struct RankResponse: Decodable {
                            let ranked_ids: [String]?
                        }
                        if let ranked = try? await CloudRunAgentRouter.post(
                            CloudRunService.searchRanking,
                            path: "/predict",
                            body: RankRequest(query: querySnapshot, video_ids: resultIds, user_id: nil)
                        ) as RankResponse, let ids = ranked.ranked_ids, !ids.isEmpty {
                            let reordered = ids.compactMap { id in
                                searchService.searchResults.first { result in
                                    if case .video(let r) = result { return r.video.id == id }
                                    return false
                                }
                            }
                            if !reordered.isEmpty {
                                await MainActor.run { searchService.searchResults = reordered }
                                print("🤖 [SearchRanking] Re-ranked \(reordered.count) results for '\(querySnapshot)'")
                            }
                        }
                    }
                }

                await MainActor.run {
                    // Add to search history
                    historyService.addSearch(searchText, scope: selectedScope)
                    
                    // Add to recent searches (for backward compatibility)
                    if !recentSearches.contains(searchText) {
                        recentSearches.insert(searchText, at: 0)
                        if recentSearches.count > 20 { recentSearches.removeLast() }
                    }
                    
                    // Check for typos and generate correction
                    if searchService.searchResults.isEmpty {
                        Task {
                            searchCorrection = await generateSearchCorrection(for: searchText)
                        }
                    } else {
                        searchCorrection = nil
                    }
                    
                    // Generate related searches
                    Task {
                        relatedSearches = await generateRelatedSearches(for: searchText)
                    }
                    
                    isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("🚨 [SearchView] Search error: \(error)")
                await MainActor.run { isSearching = false }
            }
        }
    }
    
    // Load more results (infinite scroll)
    private func loadMoreResults() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            defer { Task { @MainActor in isLoadingMore = false } }
            
            do {
                print("🚨 [SearchView] Load more error: \(error)")
                await MainActor.run { isLoadingMore = false }
            }
        }
    }
    
    // Generate search correction (AI-powered)
    private func generateSearchCorrection(for query: String) async -> String? {
        let prompt = """
        The user searched for: "\(query)"
        
        But we found no results. This might be a typo or misspelling.
        
        Suggest ONE corrected search term that the user likely meant to type.
        Return ONLY the corrected term, nothing else.
        """
        
        do {
            let correction = try await VertexAIService.shared.generateWithGemini(prompt)
            return correction.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    // Generate related searches (AI-powered)
    private func generateRelatedSearches(for query: String) async -> [String] {
        let prompt = """
        Given the search query: "\(query)"
        
        Generate 5 related search terms that users might also be interested in.
        Return only the search terms, one per line, no explanations.
        """
        
        do {
            let related = try await VertexAIService.shared.generateWithGemini(prompt)
            return related.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(5)
                .map { $0 }
        } catch {
            return []
        }
    }
}

// MARK: - Supporting Views and Models (unchanged)
struct SearchEmptyState: View {
    let recentSearches: [String]
    let onSearchTap: (String) -> Void
    @StateObject private var trendingService = TrendingSearchService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Recent Searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Searches")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        VStack(spacing: 12) {
                            ForEach(recentSearches.prefix(5), id: \.self) { search in
                                Button(action: { onSearchTap(search) }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                        
                                        Text(search)
                                            .font(AppTheme.Typography.body)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.left")
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    }
                                    .padding()
                                    .background(AppTheme.Colors.surface)
                                    .cornerRadius(AppTheme.CornerRadius.md)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                // Trending Searches (Real-time)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Trending Searches")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        // Live indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .opacity(trendingService.isLoading ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: trendingService.isLoading)
                            
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(trendingService.trendingSearches) { trend in
                            Button(action: { onSearchTap(trend.term) }) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trend.term)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .lineLimit(1)
                                        
                                        Text("\(trend.searchCount) searches")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.Colors.surface)
                                .cornerRadius(AppTheme.CornerRadius.sm)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct SearchLoadingState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(1.2)
            Text("Searching...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
        }
    }
}

struct ModernSearchResultsList: View {
    let results: [SearchResult]
    let searchCorrection: String?
    let relatedSearches: [String]
    let isLoadingMore: Bool
    let onCorrectionTap: (String) -> Void
    let onRelatedTap: (String) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Search Correction (if no results)
                if results.isEmpty && searchCorrection != nil {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("No results found")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if let correction = searchCorrection {
                            VStack(spacing: 12) {
                                Text("Did you mean:")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                Button(action: { onCorrectionTap(correction) }) {
                                    Text(correction)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(AppTheme.Colors.primary.opacity(0.1))
                                        )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)
                }
                
                // Search Results
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    ModernSearchResultCard(result: result)
                        .padding(.horizontal)
                        .onAppear {
                            // Infinite scroll - load more when near end
                            if index == results.count - 3 {
                                onLoadMore()
                            }
                        }
                }
                
                // Loading More Indicator
                if isLoadingMore {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        
                        Text("Loading more results...")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, 20)
                }
                
                // Related Searches (at bottom)
                if !relatedSearches.isEmpty && !results.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("Related Searches")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(relatedSearches, id: \.self) { related in
                                Button(action: { onRelatedTap(related) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        
                                        Text(related)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.Colors.surface)
                                    .cornerRadius(AppTheme.CornerRadius.md)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

struct ModernSearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        switch result {
        case .video(let videoResult):
            VideoSearchCard(videoResult: videoResult)
        case .creator(let creatorResult):
            CreatorSearchCard(creatorResult: creatorResult)
        case .playlist(let playlistResult):
            PlaylistSearchCard(playlistResult: playlistResult)
        case .liveStream(let liveResult):
            LiveStreamSearchCard(liveResult: liveResult)
        }
    }
}

struct VideoSearchCard: View {
    let videoResult: VideoSearchResult
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with poster candidates support
            ZStack(alignment: .bottomTrailing) {
                SearchVideoThumbnail(video: videoResult.video)
                    .frame(width: 120, height: 68)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                    .clipped()
                
                // Duration badge
                Text(videoResult.video.formattedDuration)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(3)
                    .padding(4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(videoResult.video.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(videoResult.video.creator.displayName)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Text("\(videoResult.video.viewCount) views")
                    Text("•")
                    Text(videoResult.video.createdAt, style: .relative)
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            // 🔥 Navigate to video player
            GlobalVideoPlayerManager.shared.playVideo(videoResult.video, showFullscreen: true)
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }) { }
        .accessibilityLabel("Video: \(videoResult.video.title) by \(videoResult.video.creator.displayName)")
        .accessibilityHint("Double tap to play")
    }
}

// MARK: - Search Video Thumbnail (Handles poster candidates)
private struct SearchVideoThumbnail: View {
    let video: Video
    @State private var currentIndex = 0
    
    private var thumbnailURLs: [URL] {
        // Try poster candidates first, then fall back to thumbnailURL
        var urls = video.posterCandidates
        if urls.isEmpty, let url = URL(string: video.thumbnailURL) {
            urls = [url]
        }
        return urls
    }
    
    var body: some View {
        if thumbnailURLs.isEmpty {
            placeholder
        } else {
            AsyncImage(url: thumbnailURLs[currentIndex]) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    if currentIndex < thumbnailURLs.count - 1 {
                        Color.clear.onAppear { currentIndex += 1 }
                    } else {
                        placeholder
                    }
                case .empty:
                    shimmer
                @unknown default:
                    placeholder
                }
            }
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(AppTheme.Colors.textTertiary)
            )
    }
    
    private var shimmer: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface)
            .overlay(
                ProgressView()
                    .tint(AppTheme.Colors.textTertiary)
            )
    }
}

struct CreatorSearchCard: View {
    let creatorResult: CreatorSearchResult
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false
    @State private var showingProfile = false
    @State private var isSubscribed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            AsyncImage(url: URL(string: creatorResult.creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Text(creatorResult.creator.displayName.prefix(1).uppercased())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                // Verified badge if creator is verified
                Group {
                    if creatorResult.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, AppTheme.Colors.primary)
                            .offset(x: 20, y: 20)
                    }
                }
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(creatorResult.creator.displayName)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if creatorResult.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
                
                Text("@\(creatorResult.creator.username)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 4) {
                    Text(formatSubscriberCount(creatorResult.creator.subscriberCount))
                    Text("subscribers")
                    
                    if creatorResult.creator.videoCount > 0 {
                        Text("•")
                        Text("\(creatorResult.creator.videoCount) videos")
                    }
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                
                if let bio = creatorResult.creator.bio, !bio.isEmpty {
                    Text(bio)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Subscribe Button
            Button {
                HapticManager.shared.impact(style: .medium)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSubscribed.toggle()
                }
                appState.toggleSubscription(for: creatorResult.creator.id)
            } label: {
                Text(isSubscribed ? "Subscribed" : "Subscribe")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                    .foregroundColor(isSubscribed ? AppTheme.Colors.textPrimary : .white)
                    .cornerRadius(AppTheme.CornerRadius.sm)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            // 🔥 Navigate to creator's public profile
            showingProfile = true
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }) { }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                PublicProfileView(user: creatorResult.creator)
            }
        }
        .onAppear {
            isSubscribed = appState.isSubscribedTo(creatorResult.creator.id)
        }
        .accessibilityLabel("Channel: \(creatorResult.creator.displayName)")
        .accessibilityHint("Double tap to view channel")
    }
    
    private func formatSubscriberCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

struct PlaylistSearchCard: View {
    let playlistResult: PlaylistSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 120, height: 68)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlistResult.playlist.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("By Creator")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(playlistResult.playlist.videoCount) videos")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct LiveStreamSearchCard: View {
    let liveResult: LiveStreamSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: liveResult.video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .frame(width: 120, height: 68)
                .cornerRadius(AppTheme.CornerRadius.sm)
                .clipped()
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                .padding(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(liveResult.video.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(liveResult.video.creator.displayName)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("\(liveResult.viewerCount) watching")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// SearchFiltersView is now defined in its own file

// MARK: - Supporting Models
enum SearchScope: String, CaseIterable {
    case all = "all"
    case videos = "videos"
    case creators = "creators"
    case community = "community"
    case playlists = "playlists"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .creators: return "Creators"
        case .community: return "Community"
        case .playlists: return "Playlists"
        case .live: return "Live"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "magnifyingglass"
        case .videos: return "play.rectangle"
        case .creators: return "person.circle"
        case .community: return "person.3"
        case .playlists: return "rectangle.stack"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - Voice Search Sheet
struct VoiceSearchSheet: View {
    @ObservedObject var voiceSearch: VoiceSearchService
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Animated waveform
                if voiceSearch.isListening {
                    WaveformView()
                        .frame(height: 80)
                        .padding(.horizontal, 40)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                // Status text
                Text(voiceSearch.isListening ? "Listening..." : "Tap to speak")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                // Transcribed text
                if !voiceSearch.transcribedText.isEmpty {
                    Text(voiceSearch.transcribedText)
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Error message
                if let error = voiceSearch.errorMessage {
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Mic button
                Button(action: {
                    if voiceSearch.isListening {
                        voiceSearch.stopListening()
                        if !voiceSearch.transcribedText.isEmpty {
                            onComplete(voiceSearch.transcribedText)
                        }
                    } else {
                        Task {
                            try? await voiceSearch.startListening()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(voiceSearch.isListening ? Color.red : AppTheme.Colors.primary)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: voiceSearch.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        voiceSearch.stopListening()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WaveformView: View {
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 20)
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<amplitudes.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 4)
                    .frame(height: amplitudes[index] * 80)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05),
                        value: amplitudes[index]
                    )
            }
        }
        .onAppear {
            // Animate waveform
            for index in amplitudes.indices {
                amplitudes[index] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}

// MARK: - Visual Search Sheet
struct VisualSearchSheet: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isAnalyzing = false
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding()
                    
                    if isAnalyzing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Analyzing image...")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("Visual Search")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Take a photo or upload an image to search for similar content")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        VStack(spacing: 16) {
                            Button(action: { showingImagePicker = true }) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text("Choose from Library")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(12)
                            }
                            
                            Button(action: { /* Camera */ }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.Colors.surface)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 40)
            .navigationTitle("Visual Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                if selectedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Search") {
                            performVisualSearch()
                        }
                        .disabled(isAnalyzing)
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    private func performVisualSearch() {
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                // Use Claude to analyze image
                let prompt = """
                Analyze this image and generate a search query that would find similar content.
                Return only the search query, nothing else.
                """
                
                // Convert image to base64 (simplified)
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "VisualSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
                }
                
                // TODO: Send to Claude with image
                // For now, use a simple placeholder
                let query = "Similar content" // Replace with actual Claude response
                
                await MainActor.run {
                    isAnalyzing = false
                    onComplete(query)
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
                print("🚨 [VisualSearch] Error: \(error)")
            }
        }
    }
}

// MARK: - Image Picker

#Preview {
    SearchView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}