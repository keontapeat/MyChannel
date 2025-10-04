// Advanced Search System with Filters and Better Discovery
class AdvancedSearchEngine {
    constructor() {
        this.searchIndex = new Map();
        this.searchHistory = this.loadSearchHistory();
        this.trendingQueries = ['music videos', 'gaming highlights', 'cooking tutorials', 'tech reviews'];
        this.filters = {
            type: 'all',
            duration: 'all', 
            uploadDate: 'all',
            quality: 'all',
            sortBy: 'relevance'
        };
        this.isVoiceSearching = false;
        this.recognition = null;
        this.currentResults = [];
        this.searchAnalytics = {
            queries: new Map(),
            clickThroughs: new Map(),
            abandonedSearches: 0
        };
    }

    init() {
        this.setupSearchInterface();
        this.setupVoiceSearch();
        this.setupFilters();
        this.buildSearchIndex();
        this.setupKeyboardShortcuts();
        this.loadTrendingQueries();
    }

    // Enhanced search interface with filters
    setupSearchInterface() {
        const searchContainer = document.querySelector('.search-container');
        if (!searchContainer) return;

        // Add search filters UI
        const filtersHTML = `
            <div class="search-filters" id="searchFilters" style="display: none;">
                <div class="filter-group">
                    <label>Type:</label>
                    <select id="typeFilter" class="filter-select">
                        <option value="all">All</option>
                        <option value="videos">Videos</option>
                        <option value="channels">Channels</option>
                        <option value="playlists">Playlists</option>
                        <option value="live">Live</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label>Duration:</label>
                    <select id="durationFilter" class="filter-select">
                        <option value="all">Any duration</option>
                        <option value="short">Under 4 minutes</option>
                        <option value="medium">4-20 minutes</option>
                        <option value="long">Over 20 minutes</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label>Upload date:</label>
                    <select id="uploadDateFilter" class="filter-select">
                        <option value="all">Any time</option>
                        <option value="hour">Last hour</option>
                        <option value="today">Today</option>
                        <option value="week">This week</option>
                        <option value="month">This month</option>
                        <option value="year">This year</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label>Quality:</label>
                    <select id="qualityFilter" class="filter-select">
                        <option value="all">Any quality</option>
                        <option value="hd">HD (720p+)</option>
                        <option value="fullhd">Full HD (1080p+)</option>
                        <option value="4k">4K (2160p+)</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label>Sort by:</label>
                    <select id="sortByFilter" class="filter-select">
                        <option value="relevance">Relevance</option>
                        <option value="upload_date">Upload date</option>
                        <option value="view_count">View count</option>
                        <option value="rating">Rating</option>
                        <option value="title">Title A-Z</option>
                    </select>
                </div>
                
                <button class="btn btn-sm btn-secondary" onclick="advancedSearch.resetFilters()">
                    Reset filters
                </button>
            </div>
        `;

        // Add filters toggle button
        const searchInput = document.getElementById('searchInput');
        const filtersBtn = document.createElement('button');
        filtersBtn.className = 'search-filters-btn';
        filtersBtn.innerHTML = '🔧 Filters';
        filtersBtn.onclick = () => this.toggleFilters();
        
        searchContainer.appendChild(filtersBtn);
        searchContainer.insertAdjacentHTML('beforeend', filtersHTML);

        // Enhanced search input with better suggestions
        this.setupEnhancedInput();
    }

    setupEnhancedInput() {
        const searchInput = document.getElementById('searchInput');
        if (!searchInput) return;

        // Add search suggestions container
        const suggestionsContainer = document.createElement('div');
        suggestionsContainer.className = 'search-suggestions';
        suggestionsContainer.id = 'searchSuggestions';
        searchInput.parentNode.appendChild(suggestionsContainer);

        let searchTimeout;
        searchInput.addEventListener('input', (e) => {
            clearTimeout(searchTimeout);
            const query = e.target.value.trim();
            
            if (query.length === 0) {
                this.showTrendingSuggestions();
                return;
            }

            searchTimeout = setTimeout(() => {
                this.performSearch(query);
                this.showSearchSuggestions(query);
            }, 150);
        });

        searchInput.addEventListener('focus', () => {
            if (searchInput.value.trim() === '') {
                this.showTrendingSuggestions();
            }
        });

        // Hide suggestions when clicking outside
        document.addEventListener('click', (e) => {
            if (!searchInput.contains(e.target) && !suggestionsContainer.contains(e.target)) {
                suggestionsContainer.style.display = 'none';
            }
        });

        // Keyboard navigation for suggestions
        searchInput.addEventListener('keydown', (e) => {
            this.handleSearchKeyboard(e);
        });
    }

    // Voice search with better recognition
    setupVoiceSearch() {
        const voiceBtn = document.getElementById('voiceSearchBtn');
        if (!voiceBtn) return;

        // Check for speech recognition support
        if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
            const SpeechRecognition = window.webkitSpeechRecognition || window.SpeechRecognition;
            this.recognition = new SpeechRecognition();
            
            this.recognition.continuous = false;
            this.recognition.interimResults = true;
            this.recognition.lang = 'en-US';

            this.recognition.onstart = () => {
                this.isVoiceSearching = true;
                voiceBtn.classList.add('listening');
                voiceBtn.innerHTML = '🎤 Listening...';
            };

            this.recognition.onresult = (event) => {
                let finalTranscript = '';
                let interimTranscript = '';

                for (let i = event.resultIndex; i < event.results.length; i++) {
                    const transcript = event.results[i][0].transcript;
                    if (event.results[i].isFinal) {
                        finalTranscript += transcript;
                    } else {
                        interimTranscript += transcript;
                    }
                }

                const searchInput = document.getElementById('searchInput');
                if (finalTranscript) {
                    searchInput.value = finalTranscript;
                    this.performSearch(finalTranscript);
                    this.trackSearchAnalytics(finalTranscript, 'voice');
                } else if (interimTranscript) {
                    searchInput.placeholder = `Listening: "${interimTranscript}"`;
                }
            };

            this.recognition.onend = () => {
                this.isVoiceSearching = false;
                voiceBtn.classList.remove('listening');
                voiceBtn.innerHTML = '🎤';
                document.getElementById('searchInput').placeholder = 'Search videos, channels, and more...';
            };

            this.recognition.onerror = (event) => {
                console.warn('Voice search error:', event.error);
                this.recognition.onend();
            };

            voiceBtn.onclick = () => {
                if (this.isVoiceSearching) {
                    this.recognition.stop();
                } else {
                    this.recognition.start();
                }
            };
        } else {
            voiceBtn.style.display = 'none';
        }
    }

    // Advanced filters setup
    setupFilters() {
        ['typeFilter', 'durationFilter', 'uploadDateFilter', 'qualityFilter', 'sortByFilter'].forEach(filterId => {
            const filterElement = document.getElementById(filterId);
            if (filterElement) {
                filterElement.addEventListener('change', (e) => {
                    const filterType = filterId.replace('Filter', '').replace('sortBy', 'sortBy');
                    this.filters[filterType] = e.target.value;
                    this.applyFilters();
                });
            }
        });
    }

    // Keyboard shortcuts for power users
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + K to focus search
            if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                e.preventDefault();
                document.getElementById('searchInput')?.focus();
            }
            
            // Escape to clear search
            if (e.key === 'Escape' && document.activeElement?.id === 'searchInput') {
                this.clearSearch();
            }
            
            // Alt + F to toggle filters
            if (e.altKey && e.key === 'f') {
                e.preventDefault();
                this.toggleFilters();
            }
        });
    }

    // Enhanced search algorithm
    performSearch(query) {
        if (!query || query.length < 2) return;

        // Track search analytics
        this.trackSearchAnalytics(query, 'text');

        // Get search results with ranking
        const results = this.searchWithRanking(query);
        
        // Apply filters
        const filteredResults = this.applyFiltersToResults(results);
        
        // Sort results
        const sortedResults = this.sortResults(filteredResults);
        
        this.currentResults = sortedResults;
        this.renderSearchResults(sortedResults, query);
        
        // Update search history
        this.updateSearchHistory(query);
    }

    searchWithRanking(query) {
        const results = [];
        const queryTerms = query.toLowerCase().split(' ');
        
        // Search through different content types
        const searchSources = [
            { data: window.videoLibrary || [], type: 'video', weight: 1.0 },
            { data: window.fallbackMovies || [], type: 'movie', weight: 0.9 },
            { data: window.musicLibrary || [], type: 'music', weight: 0.8 },
            { data: window.liveTVChannels || [], type: 'live', weight: 0.7 }
        ];

        searchSources.forEach(source => {
            source.data.forEach(item => {
                const score = this.calculateRelevanceScore(item, queryTerms, source.weight);
                if (score > 0) {
                    results.push({
                        ...item,
                        type: source.type,
                        relevanceScore: score,
                        searchQuery: query
                    });
                }
            });
        });

        return results.sort((a, b) => b.relevanceScore - a.relevanceScore);
    }

    calculateRelevanceScore(item, queryTerms, typeWeight) {
        let score = 0;
        const title = (item.title || '').toLowerCase();
        const description = (item.description || '').toLowerCase();
        const tags = (item.tags || []).join(' ').toLowerCase();
        
        queryTerms.forEach(term => {
            // Title matches (highest weight)
            if (title.includes(term)) {
                score += title.startsWith(term) ? 10 : 5;
            }
            
            // Description matches
            if (description.includes(term)) {
                score += 3;
            }
            
            // Tag matches
            if (tags.includes(term)) {
                score += 2;
            }
            
            // Exact phrase bonus
            if (title.includes(queryTerms.join(' '))) {
                score += 15;
            }
        });

        // Apply type weight and popularity boost
        score *= typeWeight;
        
        // Boost popular content
        if (item.views) {
            score += Math.log10(item.views + 1) * 0.1;
        }
        
        // Boost recent content
        if (item.uploadDate) {
            const daysSince = (Date.now() - new Date(item.uploadDate)) / (1000 * 60 * 60 * 24);
            score += Math.max(0, (30 - daysSince) * 0.1);
        }

        return score;
    }

    applyFiltersToResults(results) {
        return results.filter(item => {
            // Type filter
            if (this.filters.type !== 'all' && item.type !== this.filters.type) {
                return false;
            }

            // Duration filter
            if (this.filters.duration !== 'all') {
                const duration = item.duration || 0;
                switch (this.filters.duration) {
                    case 'short': if (duration >= 240) return false; break;
                    case 'medium': if (duration < 240 || duration >= 1200) return false; break;
                    case 'long': if (duration < 1200) return false; break;
                }
            }

            // Upload date filter
            if (this.filters.uploadDate !== 'all' && item.uploadDate) {
                const uploadDate = new Date(item.uploadDate);
                const now = new Date();
                const diffHours = (now - uploadDate) / (1000 * 60 * 60);
                
                switch (this.filters.uploadDate) {
                    case 'hour': if (diffHours > 1) return false; break;
                    case 'today': if (diffHours > 24) return false; break;
                    case 'week': if (diffHours > 168) return false; break;
                    case 'month': if (diffHours > 720) return false; break;
                    case 'year': if (diffHours > 8760) return false; break;
                }
            }

            // Quality filter
            if (this.filters.quality !== 'all') {
                const quality = item.quality || 'sd';
                switch (this.filters.quality) {
                    case 'hd': if (!['hd', 'fullhd', '4k'].includes(quality)) return false; break;
                    case 'fullhd': if (!['fullhd', '4k'].includes(quality)) return false; break;
                    case '4k': if (quality !== '4k') return false; break;
                }
            }

            return true;
        });
    }

    sortResults(results) {
        switch (this.filters.sortBy) {
            case 'upload_date':
                return results.sort((a, b) => new Date(b.uploadDate || 0) - new Date(a.uploadDate || 0));
            case 'view_count':
                return results.sort((a, b) => (b.views || 0) - (a.views || 0));
            case 'rating':
                return results.sort((a, b) => (b.rating || 0) - (a.rating || 0));
            case 'title':
                return results.sort((a, b) => (a.title || '').localeCompare(b.title || ''));
            case 'relevance':
            default:
                return results.sort((a, b) => b.relevanceScore - a.relevanceScore);
        }
    }

    renderSearchResults(results, query) {
        const searchContent = document.getElementById('search-content');
        if (!searchContent) return;

        if (results.length === 0) {
            searchContent.innerHTML = `
                <div class="no-results">
                    <div class="no-results-icon">🔍</div>
                    <h3>No results found for "${query}"</h3>
                    <p>Try different keywords or check your spelling</p>
                    <div class="search-suggestions-alt">
                        <p>Suggested searches:</p>
                        ${this.trendingQueries.map(q => `<button class="suggestion-chip" onclick="advancedSearch.searchFor('${q}')">${q}</button>`).join('')}
                    </div>
                </div>
            `;
            return;
        }

        const resultsHTML = `
            <div class="search-header">
                <h2>Search Results for "${query}" (${results.length} ${results.length === 1 ? 'result' : 'results'})</h2>
                <div class="search-meta">
                    <span>Sorted by ${this.filters.sortBy.replace('_', ' ')}</span>
                    ${Object.values(this.filters).some(f => f !== 'all' && f !== 'relevance') ? 
                        '<span class="filters-active">• Filters applied</span>' : ''}
                </div>
            </div>
            <div class="search-results-grid">
                ${results.slice(0, 50).map(item => this.renderSearchResultItem(item)).join('')}
            </div>
            ${results.length > 50 ? `<div class="load-more-results">
                <button class="btn btn-secondary" onclick="advancedSearch.loadMoreResults()">
                    Load more results
                </button>
            </div>` : ''}
        `;

        searchContent.innerHTML = resultsHTML;
    }

    renderSearchResultItem(item) {
        const thumbnail = item.thumbnail || '/assets/MyChannel.imageset/MyChannelLaunch.PNG';
        const duration = item.duration ? this.formatDuration(item.duration) : '';
        const views = item.views ? this.formatViews(item.views) : '';
        const uploadDate = item.uploadDate ? this.formatUploadDate(item.uploadDate) : '';

        return `
            <div class="search-result-item" onclick="advancedSearch.selectResult('${item.id}', '${item.type}')">
                <div class="result-thumbnail">
                    <img src="${thumbnail}" alt="${item.title}" loading="lazy">
                    ${duration ? `<div class="video-duration">${duration}</div>` : ''}
                    <div class="result-type-badge">${item.type}</div>
                </div>
                <div class="result-info">
                    <h3 class="result-title">${item.title}</h3>
                    <div class="result-meta">
                        ${views ? `<span>${views} views</span>` : ''}
                        ${uploadDate ? `<span>${uploadDate}</span>` : ''}
                        ${item.channel ? `<span>${item.channel}</span>` : ''}
                    </div>
                    ${item.description ? `<p class="result-description">${item.description.substring(0, 120)}...</p>` : ''}
                </div>
            </div>
        `;
    }

    // Utility functions
    toggleFilters() {
        const filters = document.getElementById('searchFilters');
        if (filters) {
            filters.style.display = filters.style.display === 'none' ? 'block' : 'none';
        }
    }

    resetFilters() {
        this.filters = {
            type: 'all',
            duration: 'all',
            uploadDate: 'all',
            quality: 'all',
            sortBy: 'relevance'
        };
        
        // Reset UI
        ['typeFilter', 'durationFilter', 'uploadDateFilter', 'qualityFilter', 'sortByFilter'].forEach(id => {
            const element = document.getElementById(id);
            if (element) element.value = 'all';
        });
        
        // Re-run search if there's a current query
        const searchInput = document.getElementById('searchInput');
        if (searchInput?.value) {
            this.performSearch(searchInput.value);
        }
    }

    searchFor(query) {
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.value = query;
            this.performSearch(query);
            showTab('search');
        }
    }

    selectResult(itemId, itemType) {
        // Track click-through
        this.trackClickThrough(itemId, itemType);
        
        // Handle different result types
        switch (itemType) {
            case 'video':
            case 'movie':
                // Play video
                console.log(`Playing ${itemType}:`, itemId);
                break;
            case 'channel':
                // Go to channel
                console.log('Opening channel:', itemId);
                break;
            case 'live':
                // Join live stream
                console.log('Joining live stream:', itemId);
                break;
        }
    }

    // Analytics and tracking
    trackSearchAnalytics(query, method = 'text') {
        const count = this.searchAnalytics.queries.get(query) || 0;
        this.searchAnalytics.queries.set(query, count + 1);
        
        // Send to analytics service if available
        if (window.analytics) {
            window.analytics.track('search_query', {
                query,
                method,
                timestamp: Date.now()
            });
        }
    }

    trackClickThrough(itemId, itemType) {
        const key = `${itemType}:${itemId}`;
        const count = this.searchAnalytics.clickThroughs.get(key) || 0;
        this.searchAnalytics.clickThroughs.set(key, count + 1);
    }

    // Helper functions
    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        if (hours > 0) {
            return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        }
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }

    formatViews(views) {
        if (views >= 1000000) {
            return `${(views / 1000000).toFixed(1)}M`;
        } else if (views >= 1000) {
            return `${(views / 1000).toFixed(1)}K`;
        }
        return views.toString();
    }

    formatUploadDate(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const diffTime = Math.abs(now - date);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
        if (diffDays < 365) return `${Math.floor(diffDays / 30)} months ago`;
        return `${Math.floor(diffDays / 365)} years ago`;
    }

    loadSearchHistory() {
        try {
            return JSON.parse(localStorage.getItem('searchHistory') || '[]');
        } catch {
            return [];
        }
    }

    updateSearchHistory(query) {
        this.searchHistory = this.searchHistory.filter(q => q !== query);
        this.searchHistory.unshift(query);
        this.searchHistory = this.searchHistory.slice(0, 10);
        localStorage.setItem('searchHistory', JSON.stringify(this.searchHistory));
    }

    loadTrendingQueries() {
        // In a real app, this would come from an API
        this.trendingQueries = [
            'music videos', 'gaming highlights', 'cooking tutorials', 'tech reviews',
            'workout routines', 'travel vlogs', 'comedy skits', 'news updates'
        ];
    }

    showTrendingSuggestions() {
        const suggestions = document.getElementById('searchSuggestions');
        if (!suggestions) return;
        
        suggestions.innerHTML = `
            <div class="suggestions-section">
                <h4>Trending searches</h4>
                ${this.trendingQueries.map(query => 
                    `<div class="suggestion-item" onclick="advancedSearch.searchFor('${query}')">${query}</div>`
                ).join('')}
            </div>
            ${this.searchHistory.length > 0 ? `
                <div class="suggestions-section">
                    <h4>Recent searches</h4>
                    ${this.searchHistory.map(query => 
                        `<div class="suggestion-item" onclick="advancedSearch.searchFor('${query}')">${query}</div>`
                    ).join('')}
                </div>
            ` : ''}
        `;
        suggestions.style.display = 'block';
    }

    clearSearch() {
        const searchInput = document.getElementById('searchInput');
        const suggestions = document.getElementById('searchSuggestions');
        
        if (searchInput) searchInput.value = '';
        if (suggestions) suggestions.style.display = 'none';
        
        this.currentResults = [];
    }
}

// Initialize advanced search
const advancedSearch = new AdvancedSearchEngine();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => advancedSearch.init());
} else {
    advancedSearch.init();
}



