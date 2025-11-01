// MyChannel Web App

class MyChannelApp {
    constructor() {
        this.currentUser = null;
        this.videos = [];
        this.channels = [];
        this.searchResults = [];
        this.currentCategory = 'all';
        this.currentVideo = null;
        
        this.init();
    }
    
    async init() {
        await this.loadInitialData();
        this.setupEventListeners();
        this.renderContent();
        this.detectUserRegion();
    }
    
    async loadInitialData() {
        try {
            // Load featured and trending videos
            this.videos = await this.fetchVideos();
            this.channels = await this.fetchLiveChannels();
            
            // Load user data if authenticated
            if (this.isAuthenticated()) {
                this.currentUser = await this.fetchCurrentUser();
                await this.loadPersonalizedContent();
            }
        } catch (error) {
            console.error('Failed to load initial data:', error);
            this.showError('Failed to load content. Please refresh the page.');
        }
    }
    
    setupEventListeners() {
        // Search
        document.getElementById('searchInput').addEventListener('input', this.debounce(this.handleSearchInput.bind(this), 300));
        document.getElementById('searchInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.performSearch();
        });
        
        // Category tabs
        document.querySelectorAll('.category-tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                const category = e.target.dataset.category;
                this.switchCategory(category);
            });
        });
        
        // Mobile menu
        document.addEventListener('click', (e) => {
            if (e.target.closest('.user-avatar')) {
                this.toggleUserMenu();
            } else if (!e.target.closest('.user-dropdown')) {
                this.closeUserMenu();
            }
        });
        
        // Keyboard navigation
        document.addEventListener('keydown', this.handleKeyNavigation.bind(this));
        
        // Resize handler
        window.addEventListener('resize', this.debounce(this.handleResize.bind(this), 250));
    }
    
    async fetchVideos() {
        try {
            const response = await fetch('/api/videos?limit=50');
            if (response.ok) {
                const data = await response.json();
                return data.videos || this.getMockVideos();
            }
        } catch (error) {
            console.error('API fetch failed:', error);
        }
        return this.getMockVideos();
    }
    
    async fetchLiveChannels() {
        try {
            const response = await fetch('/api/live/channels?limit=12');
            if (response.ok) {
                const data = await response.json();
                return data.channels || this.getMockChannels();
            }
        } catch (error) {
            console.error('API fetch failed:', error);
        }
        return this.getMockChannels();
    }
    
    async fetchCurrentUser() {
        try {
            const token = localStorage.getItem('auth_token');
            if (!token) return null;
            
            const response = await fetch('/api/user/me', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            
            if (response.ok) {
                return await response.json();
            }
        } catch (error) {
            console.error('Failed to fetch user:', error);
        }
        return null;
    }
    
    async loadPersonalizedContent() {
        if (!this.currentUser) return;
        
        try {
            const response = await fetch(`/api/recommendations?userId=${this.currentUser.id}&limit=20`, {
                headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` }
            });
            
            if (response.ok) {
                const data = await response.json();
                this.renderPersonalizedSection(data.videos || []);
            }
        } catch (error) {
            console.error('Failed to load personalized content:', error);
        }
    }
    
    renderContent() {
        this.renderForYouSection();
        this.renderTrendingSection();
        this.renderCategorySection();
        this.renderLiveChannels();
    }
    
    renderForYouSection() {
        const container = document.getElementById('forYouGrid');
        if (!container) return;
        
        const forYouVideos = this.videos.slice(0, 8);
        container.innerHTML = forYouVideos.map(video => this.createVideoCard(video)).join('');
    }
    
    renderTrendingSection() {
        const container = document.getElementById('trendingGrid');
        if (!container) return;
        
        const trendingVideos = this.videos
            .sort((a, b) => b.viewCount - a.viewCount)
            .slice(0, 12);
            
        container.innerHTML = trendingVideos.map(video => this.createVideoCard(video)).join('');
    }
    
    renderCategorySection() {
        const container = document.getElementById('categoryGrid');
        if (!container) return;
        
        let categoryVideos = this.videos;
        if (this.currentCategory !== 'all') {
            categoryVideos = this.videos.filter(video => video.category === this.currentCategory);
        }
        
        container.innerHTML = categoryVideos.slice(0, 16).map(video => this.createVideoCard(video)).join('');
    }
    
    renderLiveChannels() {
        const container = document.getElementById('liveChannelsGrid');
        if (!container) return;
        
        container.innerHTML = this.channels.map(channel => this.createChannelCard(channel)).join('');
    }
    
    createVideoCard(video) {
        const duration = this.formatDuration(video.duration);
        const timeAgo = this.timeAgo(video.createdAt);
        const viewCount = this.formatNumber(video.viewCount);
        
        return `
            <div class="video-card" onclick="playVideo('${video.id}')">
                <div class="video-thumbnail">
                    <img src="${video.thumbnailURL}" alt="${video.title}" loading="lazy">
                    <div class="video-duration">${duration}</div>
                </div>
                <div class="video-info">
                    <div class="video-title">${this.escapeHtml(video.title)}</div>
                    <div class="video-meta">
                        <div class="video-creator">${this.escapeHtml(video.creator.displayName)}</div>
                        <div class="video-stats">
                            <span>${viewCount} views</span>
                            <span>•</span>
                            <span>${timeAgo}</span>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }
    
    createChannelCard(channel) {
        const viewerCount = this.formatNumber(channel.viewerCount);
        
        return `
            <div class="channel-card" onclick="playChannel('${channel.id}')">
                <div class="channel-thumbnail">
                    <img src="${channel.logoURL}" alt="${channel.name}" loading="lazy">
                    ${channel.isLive ? `
                        <div class="live-indicator">
                            <div class="live-dot"></div>
                            LIVE
                        </div>
                    ` : ''}
                </div>
                <div class="channel-info">
                    <div class="channel-name">${this.escapeHtml(channel.name)}</div>
                    ${channel.isLive ? `
                        <div class="channel-viewers">${viewerCount} viewers</div>
                    ` : ''}
                </div>
            </div>
        `;
    }
    
    switchCategory(category) {
        this.currentCategory = category;
        
        // Update tab styles
        document.querySelectorAll('.category-tab').forEach(tab => {
            tab.classList.remove('active');
        });
        document.querySelector(`[data-category="${category}"]`).classList.add('active');
        
        // Re-render category section
        this.renderCategorySection();
        
        // Track analytics
        this.trackEvent('category_switch', { category });
    }
    
    async performSearch() {
        const query = document.getElementById('searchInput').value.trim();
        if (!query) return;
        
        try {
            const response = await fetch(`/api/search?q=${encodeURIComponent(query)}&limit=50`);
            if (response.ok) {
                const data = await response.json();
                this.searchResults = data.results || [];
                this.renderSearchResults();
            }
        } catch (error) {
            console.error('Search failed:', error);
            this.showError('Search failed. Please try again.');
        }
        
        this.trackEvent('search', { query, resultCount: this.searchResults.length });
    }
    
    handleSearchInput(e) {
        const query = e.target.value;
        if (query.length >= 2) {
            this.getSuggestions(query);
        }
    }
    
    async getSuggestions(query) {
        try {
            const response = await fetch(`/api/search/suggestions?q=${encodeURIComponent(query)}`);
            if (response.ok) {
                const data = await response.json();
                this.renderSuggestions(data.suggestions || []);
            }
        } catch (error) {
            console.error('Failed to get suggestions:', error);
        }
    }
    
    async detectUserRegion() {
        try {
            const response = await fetch('https://ipapi.co/json/');
            if (response.ok) {
                const data = await response.json();
                this.userRegion = data.country_code;
                
                // Apply region-specific content filtering
                await this.applyRegionFiltering();
            }
        } catch (error) {
            console.error('Failed to detect region:', error);
            this.userRegion = 'US'; // Default
        }
    }
    
    async applyRegionFiltering() {
        // Filter content based on region restrictions
        this.videos = this.videos.filter(video => {
            return !video.blockedRegions || !video.blockedRegions.includes(this.userRegion);
        });
        
        this.renderContent();
    }
    
    playVideo(videoId) {
        const video = this.videos.find(v => v.id === videoId);
        if (!video) return;
        
        this.currentVideo = video;
        this.showVideoModal(video);
        this.trackVideoPlay(video);
    }
    
    showVideoModal(video) {
        const modal = document.getElementById('videoModal');
        const modalVideo = document.getElementById('modalVideo');
        const title = document.getElementById('modalVideoTitle');
        const description = document.getElementById('modalVideoDescription');
        
        modal.style.display = 'flex';
        modalVideo.src = video.videoURL;
        title.textContent = video.title;
        description.textContent = video.description;
        
        // Auto-play
        modalVideo.play().catch(console.error);
        
        // Add to watch history
        this.addToWatchHistory(video.id);
        
        document.body.style.overflow = 'hidden';
    }
    
    closeVideoModal() {
        const modal = document.getElementById('videoModal');
        const modalVideo = document.getElementById('modalVideo');
        
        modal.style.display = 'none';
        modalVideo.pause();
        modalVideo.src = '';
        
        document.body.style.overflow = '';
        
        // Track watch time
        if (this.currentVideo && this.videoStartTime) {
            const watchTime = Date.now() - this.videoStartTime;
            this.trackEvent('video_watch_time', {
                videoId: this.currentVideo.id,
                watchTime: Math.round(watchTime / 1000)
            });
        }
    }
    
    toggleUserMenu() {
        const dropdown = document.getElementById('userDropdown');
        dropdown.classList.toggle('active');
    }
    
    closeUserMenu() {
        const dropdown = document.getElementById('userDropdown');
        dropdown.classList.remove('active');
    }
    
    async addToWatchHistory(videoId) {
        if (!this.isAuthenticated()) return;
        
        try {
            await fetch('/api/user/history', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
                },
                body: JSON.stringify({ videoId })
            });
        } catch (error) {
            console.error('Failed to add to watch history:', error);
        }
    }
    
    trackVideoPlay(video) {
        this.videoStartTime = Date.now();
        this.trackEvent('video_start', {
            videoId: video.id,
            title: video.title,
            creator: video.creator.displayName,
            category: video.category
        });
    }
    
    trackEvent(eventName, data = {}) {
        // Send to analytics
        if (typeof gtag !== 'undefined') {
            gtag('event', eventName, data);
        }
        
        // Send to internal analytics
        fetch('/api/analytics/track', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                event: eventName,
                data,
                timestamp: Date.now(),
                userAgent: navigator.userAgent,
                userId: this.currentUser?.id
            })
        }).catch(console.error);
    }
    
    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        }
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }
    
    formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return num.toString();
    }
    
    timeAgo(date) {
        const seconds = Math.floor((Date.now() - new Date(date).getTime()) / 1000);
        
        if (seconds < 60) return 'just now';
        if (seconds < 3600) return Math.floor(seconds / 60) + ' minutes ago';
        if (seconds < 86400) return Math.floor(seconds / 3600) + ' hours ago';
        if (seconds < 2592000) return Math.floor(seconds / 86400) + ' days ago';
        if (seconds < 31536000) return Math.floor(seconds / 2592000) + ' months ago';
        return Math.floor(seconds / 31536000) + ' years ago';
    }
    
    escapeHtml(unsafe) {
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }
    
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    handleKeyNavigation(e) {
        // Keyboard shortcuts
        if (e.ctrlKey || e.metaKey) {
            switch (e.key) {
                case 'k':
                    e.preventDefault();
                    document.getElementById('searchInput').focus();
                    break;
                case 'Escape':
                    if (document.getElementById('videoModal').style.display !== 'none') {
                        this.closeVideoModal();
                    }
                    break;
            }
        }
    }
    
    handleResize() {
        // Adjust grid layouts based on screen size
        const width = window.innerWidth;
        const videoGrid = document.querySelector('.video-grid');
        
        if (width < 768) {
            videoGrid?.classList.add('mobile-layout');
        } else {
            videoGrid?.classList.remove('mobile-layout');
        }
    }
    
    isAuthenticated() {
        return localStorage.getItem('auth_token') !== null;
    }
    
    showError(message) {
        // Show toast notification
        const toast = document.createElement('div');
        toast.className = 'toast error';
        toast.textContent = message;
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.remove();
        }, 5000);
    }
    
    showSuccess(message) {
        const toast = document.createElement('div');
        toast.className = 'toast success';
        toast.textContent = message;
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.remove();
        }, 3000);
    }
    
    getMockVideos() {
        return [
            {
                id: 'video1',
                title: 'Amazing Sunset Timelapse',
                description: 'Beautiful sunset captured in 4K quality',
                thumbnailURL: 'https://picsum.photos/400/225?random=1',
                videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                duration: 596,
                viewCount: 125000,
                likeCount: 8950,
                commentCount: 234,
                createdAt: new Date(Date.now() - 86400000).toISOString(),
                creator: {
                    id: 'creator1',
                    displayName: 'Nature Films',
                    profileImageURL: 'https://i.pravatar.cc/40?u=nature'
                },
                category: 'lifestyle'
            },
            {
                id: 'video2',
                title: 'Cooking Perfect Pasta',
                description: 'Step-by-step guide to restaurant-quality pasta',
                thumbnailURL: 'https://picsum.photos/400/225?random=2',
                videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
                duration: 720,
                viewCount: 89000,
                likeCount: 6700,
                commentCount: 189,
                createdAt: new Date(Date.now() - 172800000).toISOString(),
                creator: {
                    id: 'creator2',
                    displayName: 'Chef Studio',
                    profileImageURL: 'https://i.pravatar.cc/40?u=chef'
                },
                category: 'cooking'
            }
        ];
    }
    
    getMockChannels() {
        return [
            {
                id: 'channel1',
                name: 'MyChannel Live',
                logoURL: 'https://picsum.photos/240/135?random=live1',
                streamURL: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                isLive: true,
                viewerCount: 1250,
                category: 'entertainment'
            },
            {
                id: 'channel2',
                name: 'Gaming Central',
                logoURL: 'https://picsum.photos/240/135?random=live2',
                streamURL: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                isLive: true,
                viewerCount: 850,
                category: 'gaming'
            }
        ];
    }
}

// Global functions for onclick handlers
let app;

function playVideo(videoId) {
    app.playVideo(videoId);
}

function playChannel(channelId) {
    console.log('Playing channel:', channelId);
}

function performSearch() {
    app.performSearch();
}

function showExplore() {
    console.log('Show explore');
}

function showTrending() {
    console.log('Show trending');
}

function showAllLive() {
    console.log('Show all live');
}

function toggleTheme() {
    document.body.classList.toggle('light-theme');
    localStorage.setItem('theme', document.body.classList.contains('light-theme') ? 'light' : 'dark');
}

function showNotifications() {
    console.log('Show notifications');
}

function playHeroVideo() {
    if (app.videos.length > 0) {
        app.playVideo(app.videos[0].id);
    }
}

function addToWatchLater() {
    if (app.videos.length > 0) {
        console.log('Add to watch later:', app.videos[0].id);
        app.showSuccess('Added to Watch Later');
    }
}

function closeVideoModal() {
    app.closeVideoModal();
}

function likeVideo() {
    console.log('Like video');
    app.showSuccess('Video liked!');
}

function shareVideo() {
    if (navigator.share && app.currentVideo) {
        navigator.share({
            title: app.currentVideo.title,
            text: app.currentVideo.description,
            url: window.location.href + '?v=' + app.currentVideo.id
        });
    } else {
        // Fallback copy to clipboard
        navigator.clipboard.writeText(window.location.href).then(() => {
            app.showSuccess('Link copied to clipboard');
        });
    }
}

function saveToPlaylist() {
    console.log('Save to playlist');
    app.showSuccess('Saved to playlist');
}

function closeMobileSidebar() {
    document.getElementById('mobileSidebar').classList.remove('active');
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    app = new MyChannelApp();
    
    // Load theme preference
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'light') {
        document.body.classList.add('light-theme');
    }
});


