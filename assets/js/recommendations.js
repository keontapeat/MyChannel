// Enhanced Recommendation Engine for MyChannel
class RecommendationEngine {
    constructor() {
        this.userPreferences = this.loadUserPreferences();
        this.viewHistory = this.loadViewHistory();
        this.contentDatabase = new Map();
        this.similarityThreshold = 0.3;
        this.maxRecommendations = 20;
    }

    // Initialize recommendation system
    init() {
        this.buildContentDatabase();
        this.trackUserInteractions();
        this.setupPersonalization();
    }

    // Build content database with metadata
    buildContentDatabase() {
        // Sample content with rich metadata for better recommendations
        const content = [
            {
                id: 'trending_1', type: 'video', title: 'How to Create Amazing Content',
                categories: ['education', 'tutorial', 'creator'], duration: 632,
                views: 125000, likes: 8500, engagement: 0.068, quality: 0.9,
                creator: 'MyChannel Tips', creatorId: 'creator_1',
                tags: ['content creation', 'tutorial', 'beginner', 'tips'],
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG'
            },
            {
                id: 'music_1', type: 'video', title: 'Best Music for Content Creation',
                categories: ['music', 'background', 'creator'], duration: 945,
                views: 89000, likes: 6200, engagement: 0.070, quality: 0.85,
                creator: 'Music Hub', creatorId: 'creator_2',
                tags: ['music', 'background music', 'copyright free', 'creative'],
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG'
            },
            {
                id: 'tech_1', type: 'video', title: 'Latest Video Editing Techniques',
                categories: ['tech', 'tutorial', 'editing'], duration: 1200,
                views: 156000, likes: 12400, engagement: 0.080, quality: 0.95,
                creator: 'Tech Insider', creatorId: 'creator_3',
                tags: ['video editing', 'techniques', 'advanced', 'software'],
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG'
            },
            {
                id: 'gaming_1', type: 'video', title: 'Top Gaming Moments This Week',
                categories: ['gaming', 'entertainment', 'highlights'], duration: 780,
                views: 234000, likes: 18900, engagement: 0.081, quality: 0.88,
                creator: 'Gaming Central', creatorId: 'creator_4',
                tags: ['gaming', 'highlights', 'funny', 'compilation'],
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG'
            },
            {
                id: 'lifestyle_1', type: 'video', title: 'Morning Routine for Productivity',
                categories: ['lifestyle', 'productivity', 'wellness'], duration: 540,
                views: 98000, likes: 7800, engagement: 0.080, quality: 0.82,
                creator: 'Wellness Coach', creatorId: 'creator_5',
                tags: ['morning routine', 'productivity', 'wellness', 'habits'],
                thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG'
            }
        ];

        content.forEach(item => {
            this.contentDatabase.set(item.id, item);
        });

        console.log(`📊 Content database built with ${this.contentDatabase.size} items`);
    }

    // Track user interactions for personalization
    trackUserInteractions() {
        // Track video clicks
        document.addEventListener('click', (e) => {
            const videoCard = e.target.closest('.video-card');
            if (videoCard && videoCard.dataset.videoId) {
                this.recordInteraction('click', videoCard.dataset.videoId);
            }
        });

        // Track search queries
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                if (e.target.value.length > 2) {
                    this.recordInteraction('search', e.target.value);
                }
            });
        }

        // Track time spent on videos (simulated)
        this.trackWatchTime();
    }

    // Record user interaction
    recordInteraction(type, data, metadata = {}) {
        const interaction = {
            type,
            data,
            metadata,
            timestamp: Date.now(),
            userId: this.getCurrentUserId()
        };

        // Update user preferences based on interaction
        this.updateUserPreferences(interaction);

        // Add to view history
        if (type === 'click' || type === 'watch') {
            this.addToViewHistory(data, metadata);
        }

        console.log(`🎯 Recorded interaction: ${type}`, data);
    }

    // Update user preferences based on interactions
    updateUserPreferences(interaction) {
        const { type, data } = interaction;

        if (type === 'click' || type === 'watch') {
            const content = this.contentDatabase.get(data);
            if (content) {
                // Increase preference for categories
                content.categories.forEach(category => {
                    this.userPreferences.categories[category] = 
                        (this.userPreferences.categories[category] || 0) + 1;
                });

                // Increase preference for creator
                this.userPreferences.creators[content.creatorId] = 
                    (this.userPreferences.creators[content.creatorId] || 0) + 1;

                // Update preferred duration range
                this.updateDurationPreference(content.duration);
            }
        } else if (type === 'search') {
            // Extract keywords and update preferences
            const keywords = data.toLowerCase().split(' ');
            keywords.forEach(keyword => {
                this.userPreferences.keywords[keyword] = 
                    (this.userPreferences.keywords[keyword] || 0) + 1;
            });
        }

        this.saveUserPreferences();
    }

    // Generate personalized recommendations
    generateRecommendations(excludeIds = [], limit = 10) {
        const recommendations = [];
        const contentArray = Array.from(this.contentDatabase.values())
            .filter(content => !excludeIds.includes(content.id));

        // Score each content item
        const scoredContent = contentArray.map(content => ({
            ...content,
            score: this.calculateContentScore(content)
        }));

        // Sort by score and apply diversity
        const sorted = scoredContent.sort((a, b) => b.score - a.score);
        const diversified = this.applyDiversityFilter(sorted);

        return diversified.slice(0, limit);
    }

    // Calculate content score based on user preferences
    calculateContentScore(content) {
        let score = 0;

        // Base quality score
        score += content.quality * 20;

        // Engagement score
        score += content.engagement * 100;

        // Category preference score
        const categoryScore = content.categories.reduce((sum, category) => {
            return sum + (this.userPreferences.categories[category] || 0);
        }, 0);
        score += categoryScore * 5;

        // Creator preference score
        const creatorScore = this.userPreferences.creators[content.creatorId] || 0;
        score += creatorScore * 3;

        // Tag/keyword matching score
        const keywordScore = content.tags.reduce((sum, tag) => {
            const words = tag.split(' ');
            return sum + words.reduce((wordSum, word) => {
                return wordSum + (this.userPreferences.keywords[word.toLowerCase()] || 0);
            }, 0);
        }, 0);
        score += keywordScore * 2;

        // Duration preference score
        score += this.getDurationPreferenceScore(content.duration);

        // Freshness boost (newer content gets slight boost)
        const daysSinceCreation = (Date.now() - (content.createdAt || Date.now() - 86400000)) / 86400000;
        score += Math.max(0, 10 - daysSinceCreation);

        // Popularity boost (but not too much to avoid echo chamber)
        score += Math.log(content.views + 1) * 0.1;

        return Math.max(0, score);
    }

    // Apply diversity filter to avoid echo chamber
    applyDiversityFilter(sortedContent) {
        const diversified = [];
        const categoryCount = {};
        const creatorCount = {};

        for (const content of sortedContent) {
            let shouldInclude = true;

            // Limit content per category
            const mainCategory = content.categories[0];
            if (categoryCount[mainCategory] >= 3) {
                shouldInclude = false;
            }

            // Limit content per creator
            if (creatorCount[content.creatorId] >= 2) {
                shouldInclude = false;
            }

            if (shouldInclude) {
                diversified.push(content);
                categoryCount[mainCategory] = (categoryCount[mainCategory] || 0) + 1;
                creatorCount[content.creatorId] = (creatorCount[content.creatorId] || 0) + 1;
            }

            if (diversified.length >= this.maxRecommendations) break;
        }

        return diversified;
    }

    // Get duration preference score
    getDurationPreferenceScore(duration) {
        const preferredDuration = this.userPreferences.averageDuration || 600; // 10 minutes default
        const difference = Math.abs(duration - preferredDuration);
        return Math.max(0, 10 - (difference / 60)); // Penalty for being too far from preferred
    }

    // Update duration preference based on watch history
    updateDurationPreference(duration) {
        const current = this.userPreferences.averageDuration || 600;
        const count = this.userPreferences.durationCount || 1;
        
        // Weighted average
        this.userPreferences.averageDuration = 
            (current * count + duration) / (count + 1);
        this.userPreferences.durationCount = count + 1;
    }

    // Track simulated watch time
    trackWatchTime() {
        // Simulate watch time tracking
        setInterval(() => {
            const activeVideo = document.querySelector('.video-card.active');
            if (activeVideo && activeVideo.dataset.videoId) {
                this.recordInteraction('watch', activeVideo.dataset.videoId, {
                    watchTime: 30 // 30 seconds increment
                });
            }
        }, 30000);
    }

    // Render recommendations in a container
    renderRecommendations(containerId, options = {}) {
        const container = document.getElementById(containerId);
        if (!container) return;

        const {
            title = 'Recommended for you',
            limit = 6,
            excludeIds = [],
            showSkeleton = true
        } = options;

        // Show loading skeleton
        if (showSkeleton && window.performanceManager) {
            window.performanceManager.showSkeleton(containerId, 'cards');
        }

        // Generate recommendations
        const recommendations = this.generateRecommendations(excludeIds, limit);

        // Render content
        setTimeout(() => {
            const html = `
                <div class="recommendations-header">
                    <h3 class="section-title">${title}</h3>
                    <button class="refresh-recommendations" onclick="window.recommendationEngine.refreshRecommendations('${containerId}')">
                        🔄 Refresh
                    </button>
                </div>
                <div class="recommendations-grid">
                    ${recommendations.map(content => this.renderRecommendationCard(content)).join('')}
                </div>
            `;

            container.innerHTML = html;

            if (window.performanceManager) {
                window.performanceManager.hideSkeleton(containerId);
            }

            console.log(`📺 Rendered ${recommendations.length} recommendations in ${containerId}`);
        }, 500);
    }

    // Render individual recommendation card
    renderRecommendationCard(content) {
        const duration = this.formatDuration(content.duration);
        const views = this.formatViews(content.views);

        return `
            <div class="video-card recommendation-card" data-video-id="${content.id}" onclick="this.classList.add('active')">
                <div class="video-thumbnail">
                    <img src="${content.thumbnail}" alt="${content.title}" loading="lazy">
                    <div class="video-duration">${duration}</div>
                    <div class="recommendation-score" title="Recommendation score: ${content.score?.toFixed(1)}">
                        ${this.getScoreEmoji(content.score)}
                    </div>
                </div>
                <div class="video-info">
                    <h4 class="video-title">${content.title}</h4>
                    <div class="video-meta">
                        <span class="creator-name">${content.creator}</span>
                        <span class="video-views">${views} views</span>
                    </div>
                    <div class="recommendation-tags">
                        ${content.categories.slice(0, 2).map(cat => 
                            `<span class="rec-tag">${cat}</span>`
                        ).join('')}
                    </div>
                </div>
            </div>
        `;
    }

    // Refresh recommendations
    refreshRecommendations(containerId) {
        this.renderRecommendations(containerId, {
            title: 'Fresh recommendations',
            showSkeleton: false
        });
    }

    // Setup personalization features
    setupPersonalization() {
        // Add personalization controls to user menu
        this.addPersonalizationControls();
        
        // Initialize recommendation sections
        this.initializeRecommendationSections();
    }

    // Add personalization controls
    addPersonalizationControls() {
        const accountMenu = document.getElementById('accountMenu');
        if (accountMenu) {
            const personalizeButton = document.createElement('button');
            personalizeButton.innerHTML = '🎯 Personalize';
            personalizeButton.style.cssText = 'width:100%; padding:12px 16px; background:#fff; border:none; text-align:left; cursor:pointer;';
            personalizeButton.onclick = () => this.openPersonalizationModal();
            
            accountMenu.appendChild(personalizeButton);
        }
    }

    // Initialize recommendation sections
    initializeRecommendationSections() {
        // Add recommendations to home page
        setTimeout(() => {
            const homeContent = document.getElementById('home-content');
            if (homeContent) {
                const recSection = document.createElement('section');
                recSection.id = 'recommendations-section';
                recSection.style.cssText = 'margin: 32px 0; padding: 0 16px;';
                
                homeContent.appendChild(recSection);
                
                this.renderRecommendations('recommendations-section', {
                    title: '🎯 Recommended for you',
                    limit: 8
                });
            }
        }, 2000);
    }

    // Utility functions
    formatDuration(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }

    formatViews(views) {
        if (views >= 1000000) {
            return (views / 1000000).toFixed(1) + 'M';
        } else if (views >= 1000) {
            return (views / 1000).toFixed(1) + 'K';
        }
        return views.toString();
    }

    getScoreEmoji(score) {
        if (score >= 80) return '🔥';
        if (score >= 60) return '⭐';
        if (score >= 40) return '👍';
        return '💡';
    }

    getCurrentUserId() {
        // Return current user ID or anonymous ID
        return window.auth?.currentUser?.uid || 'anonymous_' + Date.now();
    }

    // Data persistence
    loadUserPreferences() {
        try {
            const saved = localStorage.getItem('myChannelUserPreferences');
            return saved ? JSON.parse(saved) : {
                categories: {},
                creators: {},
                keywords: {},
                averageDuration: 600,
                durationCount: 1
            };
        } catch {
            return {
                categories: {},
                creators: {},
                keywords: {},
                averageDuration: 600,
                durationCount: 1
            };
        }
    }

    saveUserPreferences() {
        try {
            localStorage.setItem('myChannelUserPreferences', JSON.stringify(this.userPreferences));
        } catch (error) {
            console.warn('Could not save user preferences:', error);
        }
    }

    loadViewHistory() {
        try {
            const saved = localStorage.getItem('myChannelViewHistory');
            return saved ? JSON.parse(saved) : [];
        } catch {
            return [];
        }
    }

    addToViewHistory(videoId, metadata = {}) {
        this.viewHistory.unshift({
            videoId,
            timestamp: Date.now(),
            ...metadata
        });

        // Keep only last 100 items
        this.viewHistory = this.viewHistory.slice(0, 100);

        try {
            localStorage.setItem('myChannelViewHistory', JSON.stringify(this.viewHistory));
        } catch (error) {
            console.warn('Could not save view history:', error);
        }
    }

    // Clear user data
    clearPersonalizationData() {
        this.userPreferences = {
            categories: {},
            creators: {},
            keywords: {},
            averageDuration: 600,
            durationCount: 1
        };
        this.viewHistory = [];
        
        try {
            localStorage.removeItem('myChannelUserPreferences');
            localStorage.removeItem('myChannelViewHistory');
        } catch (error) {
            console.warn('Could not clear personalization data:', error);
        }

        console.log('🗑️ Personalization data cleared');
    }
}

// Initialize recommendation engine
window.recommendationEngine = new RecommendationEngine();

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        window.recommendationEngine.init();
    }, 1000);
});









