// Enhanced Search System for MyChannel
class EnhancedSearch {
    constructor() {
        this.searchIndex = new Map();
        this.searchHistory = this.loadSearchHistory();
        this.suggestions = [
            '🎵 Music Videos', '🎮 Gaming', '📚 Education', '🍳 Cooking',
            '💪 Fitness', '🎨 Art', '💻 Tech', '🎬 Movies', '📺 TV Shows',
            '🎪 Entertainment', '📰 News', '🏃 Sports', '🌍 Travel', '💄 Beauty'
        ];
        this.filters = {
            type: 'all', // all, videos, channels, playlists
            duration: 'all', // all, short, medium, long
            uploadDate: 'all', // all, hour, today, week, month, year
            quality: 'all' // all, hd, 4k
        };
    }

    // Initialize search functionality
    init() {
        this.setupSearchInput();
        this.setupVoiceSearch();
        this.buildSearchIndex();
    }

    // Setup main search input with debounced suggestions
    setupSearchInput() {
        const searchInput = document.getElementById('searchInput');
        if (!searchInput) return;

        const debouncedSearch = window.performanceManager?.debounce(
            (query) => this.handleSearchInput(query), 
            300
        ) || ((query) => this.handleSearchInput(query));

        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.trim();
            if (query.length > 0) {
                debouncedSearch(query);
            } else {
                this.showSuggestions();
            }
        });

        searchInput.addEventListener('focus', () => {
            this.showSuggestions();
        });

        searchInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.performSearch(searchInput.value.trim());
            }
        });
    }

    // Handle search input and show live suggestions
    async handleSearchInput(query) {
        if (query.length < 2) {
            this.showSuggestions();
            return;
        }

        try {
            const suggestions = await this.getSuggestions(query);
            this.renderSuggestions(suggestions);
        } catch (error) {
            console.error('Search suggestions failed:', error);
        }
    }

    // Get search suggestions
    async getSuggestions(query) {
        // Simulate API call with local suggestions
        const filtered = this.suggestions.filter(suggestion => 
            suggestion.toLowerCase().includes(query.toLowerCase())
        );

        // Add search history matches
        const historyMatches = this.searchHistory.filter(item =>
            item.toLowerCase().includes(query.toLowerCase())
        ).slice(0, 3);

        // Combine and deduplicate
        const combined = [...new Set([...historyMatches, ...filtered])];
        
        return combined.slice(0, 8);
    }

    // Render search suggestions
    renderSuggestions(suggestions) {
        const container = document.getElementById('searchSuggestions');
        if (!container) return;

        if (suggestions.length === 0) {
            container.style.display = 'none';
            return;
        }

        const suggestionsHTML = suggestions.map(suggestion => `
            <div class="search-suggestion" onclick="window.enhancedSearch.selectSuggestion('${suggestion}')">
                <span class="suggestion-icon">🔍</span>
                <span class="suggestion-text">${suggestion}</span>
            </div>
        `).join('');

        container.innerHTML = suggestionsHTML;
        container.style.display = 'block';
    }

    // Show default suggestions
    showSuggestions() {
        const recent = this.searchHistory.slice(0, 4);
        const trending = this.suggestions.slice(0, 4);
        const combined = [...recent, ...trending];
        
        this.renderSuggestions(combined);
    }

    // Select a suggestion
    selectSuggestion(suggestion) {
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.value = suggestion;
            this.performSearch(suggestion);
        }
    }

    // Perform actual search
    async performSearch(query) {
        if (!query) return;

        // Add to search history
        this.addToHistory(query);

        // Hide suggestions
        const suggestions = document.getElementById('searchSuggestions');
        if (suggestions) suggestions.style.display = 'none';

        // Show loading state
        const resultsContainer = document.getElementById('search-results');
        if (resultsContainer && window.performanceManager) {
            window.performanceManager.showSkeleton('search-results', 'list');
        }

        try {
            const results = await this.searchContent(query);
            this.renderSearchResults(results, query);
        } catch (error) {
            console.error('Search failed:', error);
            if (window.performanceManager) {
                window.performanceManager.showError(
                    'search-results',
                    'Search temporarily unavailable',
                    'window.enhancedSearch.performSearch("' + query + '")'
                );
            }
        }
    }

    // Search content with filters
    async searchContent(query) {
        // Simulate search with mock data
        const mockResults = [
            {
                id: '1',
                type: 'video',
                title: 'How to Create Amazing Content',
                channel: 'MyChannel Tips',
                views: '125K views',
                duration: '10:32',
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
                uploadDate: '2 days ago'
            },
            {
                id: '2',
                type: 'video',
                title: 'Best Music for Content Creation',
                channel: 'Music Hub',
                views: '89K views',
                duration: '15:45',
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
                uploadDate: '1 week ago'
            },
            {
                id: '3',
                type: 'channel',
                title: 'Creative Studio',
                subscribers: '45K subscribers',
                thumbnail: '/assets/UserProfileAvatar.imageset/UserProfileAvatar.PNG',
                description: 'Professional content creation tutorials and tips'
            }
        ];

        // Filter results based on query and active filters
        return mockResults.filter(result => {
            const matchesQuery = result.title.toLowerCase().includes(query.toLowerCase()) ||
                               (result.channel && result.channel.toLowerCase().includes(query.toLowerCase()));
            
            const matchesType = this.filters.type === 'all' || result.type === this.filters.type;
            
            return matchesQuery && matchesType;
        });
    }

    // Render search results
    renderSearchResults(results, query) {
        const container = document.getElementById('search-results');
        if (!container) return;

        if (results.length === 0) {
            container.innerHTML = `
                <div class="no-results">
                    <div style="font-size:48px; margin-bottom:16px;">🔍</div>
                    <h3>No results found for "${query}"</h3>
                    <p>Try different keywords or check your spelling</p>
                    <div style="margin-top:20px;">
                        <h4>Suggestions:</h4>
                        <div style="display:flex; flex-wrap:wrap; gap:8px; margin-top:8px;">
                            ${this.suggestions.slice(0, 6).map(s => 
                                `<span class="suggestion-chip" onclick="window.enhancedSearch.selectSuggestion('${s}')">${s}</span>`
                            ).join('')}
                        </div>
                    </div>
                </div>
            `;
            return;
        }

        const resultsHTML = `
            <div class="search-header">
                <h3>Search results for "${query}" (${results.length})</h3>
                <div class="search-filters">
                    <select onchange="window.enhancedSearch.updateFilter('type', this.value)">
                        <option value="all">All</option>
                        <option value="video">Videos</option>
                        <option value="channel">Channels</option>
                        <option value="playlist">Playlists</option>
                    </select>
                    <select onchange="window.enhancedSearch.updateFilter('duration', this.value)">
                        <option value="all">Any duration</option>
                        <option value="short">Under 4 minutes</option>
                        <option value="medium">4-20 minutes</option>
                        <option value="long">Over 20 minutes</option>
                    </select>
                </div>
            </div>
            <div class="search-results-list">
                ${results.map(result => this.renderSearchResult(result)).join('')}
            </div>
        `;

        container.innerHTML = resultsHTML;
    }

    // Render individual search result
    renderSearchResult(result) {
        if (result.type === 'video') {
            return `
                <div class="search-result-item video-result" onclick="openVideoDetail('${result.id}')">
                    <div class="result-thumbnail">
                        <img src="${result.thumbnail}" alt="${result.title}">
                        <span class="video-duration">${result.duration}</span>
                    </div>
                    <div class="result-info">
                        <h4 class="result-title">${result.title}</h4>
                        <div class="result-meta">
                            <span class="result-channel">${result.channel}</span>
                            <span class="result-views">${result.views}</span>
                            <span class="result-date">${result.uploadDate}</span>
                        </div>
                    </div>
                </div>
            `;
        } else if (result.type === 'channel') {
            return `
                <div class="search-result-item channel-result" onclick="openChannelDetail('${result.id}')">
                    <div class="result-thumbnail channel-avatar">
                        <img src="${result.thumbnail}" alt="${result.title}">
                    </div>
                    <div class="result-info">
                        <h4 class="result-title">${result.title}</h4>
                        <div class="result-meta">
                            <span class="result-subscribers">${result.subscribers}</span>
                        </div>
                        <p class="result-description">${result.description}</p>
                    </div>
                </div>
            `;
        }
    }

    // Update search filters
    updateFilter(filterType, value) {
        this.filters[filterType] = value;
        const searchInput = document.getElementById('searchInput');
        if (searchInput && searchInput.value.trim()) {
            this.performSearch(searchInput.value.trim());
        }
    }

    // Setup voice search
    setupVoiceSearch() {
        if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
            return; // Voice search not supported
        }

        const voiceButton = document.getElementById('voiceSearchBtn');
        if (!voiceButton) return;

        voiceButton.style.display = 'block';
        voiceButton.addEventListener('click', () => this.startVoiceSearch());
    }

    // Start voice search
    startVoiceSearch() {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        const recognition = new SpeechRecognition();

        recognition.continuous = false;
        recognition.interimResults = false;
        recognition.lang = 'en-US';

        recognition.onstart = () => {
            const voiceButton = document.getElementById('voiceSearchBtn');
            if (voiceButton) voiceButton.classList.add('listening');
        };

        recognition.onresult = (event) => {
            const transcript = event.results[0][0].transcript;
            const searchInput = document.getElementById('searchInput');
            if (searchInput) {
                searchInput.value = transcript;
                this.performSearch(transcript);
            }
        };

        recognition.onend = () => {
            const voiceButton = document.getElementById('voiceSearchBtn');
            if (voiceButton) voiceButton.classList.remove('listening');
        };

        recognition.onerror = (event) => {
            console.error('Voice search error:', event.error);
            const voiceButton = document.getElementById('voiceSearchBtn');
            if (voiceButton) voiceButton.classList.remove('listening');
        };

        recognition.start();
    }

    // Build search index for better performance
    buildSearchIndex() {
        // This would typically index all content for faster searching
        // For now, we'll use the mock data structure
        console.log('Search index built');
    }

    // Search history management
    loadSearchHistory() {
        try {
            return JSON.parse(localStorage.getItem('myChannelSearchHistory') || '[]');
        } catch {
            return [];
        }
    }

    addToHistory(query) {
        if (!query || this.searchHistory.includes(query)) return;
        
        this.searchHistory.unshift(query);
        this.searchHistory = this.searchHistory.slice(0, 10); // Keep last 10
        
        try {
            localStorage.setItem('myChannelSearchHistory', JSON.stringify(this.searchHistory));
        } catch (error) {
            console.warn('Could not save search history:', error);
        }
    }

    clearHistory() {
        this.searchHistory = [];
        try {
            localStorage.removeItem('myChannelSearchHistory');
        } catch (error) {
            console.warn('Could not clear search history:', error);
        }
    }
}

// Initialize enhanced search
window.enhancedSearch = new EnhancedSearch();

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        window.enhancedSearch.init();
    }, 500);
});

