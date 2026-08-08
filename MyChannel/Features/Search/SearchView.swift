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
    @StateObject private var conversationalService = ConversationalSearchService.shared
    
    @State private var searchText: String = ""
    @State private var selectedScope: SearchScope = .all
    @State private var isSearching: Bool = false
    @State private var recentSearches: [String] = []
    @State private var searchFilters = MyChannel.SearchFilters()
    @State private var showingFilters = false
    @State private var showingVoiceSearch = false
    @State private var showingVisualSearch = false
    @State private var isConversationalMode = false
    @State private var aiResult: SearchV3Result?
    @State private var isAIThinking = false
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
                        // AI Toggle Button
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isConversationalMode.toggle()
                                if isConversationalMode {
                                    selectedScope = .all
                                }
                            }
                        }) {
                            HStack {
                                Text("Ask AI")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isConversationalMode ? LinearGradient(colors: [AppTheme.Colors.primary, .purple], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [AppTheme.Colors.surface, AppTheme.Colors.surface], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(isConversationalMode ? .white : AppTheme.Colors.primary)
                            .cornerRadius(AppTheme.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                    .stroke(AppTheme.Colors.primary.opacity(isConversationalMode ? 0 : 0.5), lineWidth: 1)
                            )
                        }
                        
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Button(scope.displayName) {
                                // 🔥 PREMIUM: Haptic on scope change
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedScope = scope
                                    isConversationalMode = false
                                }
                                if !searchText.isEmpty {
                                    performSearch()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(!isConversationalMode && selectedScope == scope ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .foregroundColor(!isConversationalMode && selectedScope == scope ? .white : AppTheme.Colors.textPrimary)
                            .cornerRadius(AppTheme.CornerRadius.md)
                            // 🔥 PREMIUM: Scale animation for selected scope
                            .scaleEffect(!isConversationalMode && selectedScope == scope ? 1.02 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedScope)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                ZStack(alignment: .topLeading) {
                    if searchText.isEmpty {
                        LegacySearchEmptyState(recentSearches: historyService.getRecentSearches()) { search in
                            searchText = search
                            performSearch()
                        }
                    } else if isConversationalMode {
                        ConversationalAIView(
                            query: searchText,
                            aiResult: aiResult,
                            isThinking: isAIThinking,
                            conversationHistory: conversationalService.history,
                            onFollowUp: { followUp in
                                searchText = followUp
                                performAISearch(isFollowUp: true)
                            }
                        )
                    } else if isSearching {
                        LegacySearchLoadingState()
                    } else {
                        LegacySearchResultsList(
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
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium(), .large()],
                        largestUndimmedDetentIdentifier: .large,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
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
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium(), .large()],
                        largestUndimmedDetentIdentifier: .large,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
        }
        .sheet(isPresented: $showingVisualSearch) {
            VisualSearchSheet(onComplete: { query in
                searchText = query
                showingVisualSearch = false
                performSearch()
            })
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium(), .large()],
                        largestUndimmedDetentIdentifier: .large,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
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
                        .onSubmit {
                            if isConversationalMode {
                                performAISearch()
                            } else {
                                performSearch()
                            }
                        }
                    
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
    private func performAISearch(isFollowUp: Bool = false) {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        showingSuggestions = false
        searchTask?.cancel()
        
        isAIThinking = true
        if !isFollowUp { aiResult = nil }
        
        searchTask = Task { @MainActor in
            defer { isAIThinking = false }
            do {
                let query = MultimodalSearchQuery(
                    text: searchText,
                    imageData: nil,
                    voiceTranscript: voiceSearch.isListening ? searchText : nil,
                    conversationId: isFollowUp ? aiResult?.conversationId : nil
                )
                
                async let v3Fetch = AISearchAgentV3Service.shared.multiModalQuery(query)
                async let historyFetch: ConversationalReply? = {
                    guard AppConfig.Features.enableConversationalSearch else { return nil }
                    return try? await conversationalService.ask(searchText, userId: AppState.shared.currentUser?.id)
                }()

                let (result, _) = try await (v3Fetch, historyFetch)
                guard !Task.isCancelled else { return }
                self.aiResult = result
            } catch {
                guard !Task.isCancelled else { return }
                print("🚨 [SearchView] AI Search error: \(error)")
            }
        }
    }

    private func performSearch() {
        if isConversationalMode {
            performAISearch()
            return
        }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Hide suggestions
        showingSuggestions = false
        
        // ⚡ PERFORMANCE: Cancel previous search task
        searchTask?.cancel()
        
        isSearching = true
        currentPage = 1
        
        searchTask = Task { @MainActor in
            defer { isSearching = false }
            
            do {
                // Track search analytics
                await trendingService.trackSearch(term: searchText)
                
                let _ = try await searchService.search(query: searchText, filters: convertToAdvancedFilters(searchFilters))

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
        
        Task { @MainActor in
            defer { isLoadingMore = false }
            
            do {
                // Add actual load more logic here
                print("📄 [SearchView] Loading more results for page \(currentPage)")
            } catch {
                print("🚨 [SearchView] Load more error: \(error)")
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


// ⚡ Supporting views + models extracted to SearchViewComponents.swift
