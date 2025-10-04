// Enhanced Creator Studio for MyChannel
class CreatorStudio {
    constructor() {
        this.analytics = {
            views: 0,
            subscribers: 0,
            revenue: 0,
            watchTime: 0,
            videos: []
        };
        this.chartInstances = new Map();
    }

    // Initialize creator studio
    async init() {
        await this.loadAnalytics();
        this.setupDashboard();
        this.setupCharts();
        this.setupRealTimeUpdates();
    }

    // Load creator analytics data
    async loadAnalytics() {
        try {
            // Simulate loading analytics data
            this.analytics = {
                views: Math.floor(Math.random() * 100000) + 50000,
                subscribers: Math.floor(Math.random() * 10000) + 5000,
                revenue: Math.floor(Math.random() * 1000) + 500,
                watchTime: Math.floor(Math.random() * 50000) + 25000,
                videos: this.generateMockVideoData(),
                demographics: this.generateDemographics(),
                trafficSources: this.generateTrafficSources(),
                revenueBreakdown: this.generateRevenueBreakdown()
            };

            console.log('Creator analytics loaded:', this.analytics);
        } catch (error) {
            console.error('Failed to load analytics:', error);
        }
    }

    // Setup main dashboard
    setupDashboard() {
        const dashboard = document.getElementById('creatorDashboard');
        if (!dashboard) return;

        dashboard.innerHTML = `
            <div class="studio-header">
                <h2>Creator Studio</h2>
                <div class="studio-actions">
                    <button class="btn-primary" onclick="window.creatorStudio.exportData()">Export Data</button>
                    <button class="btn-secondary" onclick="window.creatorStudio.refreshAnalytics()">Refresh</button>
                </div>
            </div>

            <div class="analytics-grid">
                <div class="analytics-card">
                    <div class="card-header">
                        <h3>Total Views</h3>
                        <span class="growth-indicator positive">+12.5%</span>
                    </div>
                    <div class="metric-value">${this.formatNumber(this.analytics.views)}</div>
                    <div class="metric-subtitle">Last 28 days</div>
                </div>

                <div class="analytics-card">
                    <div class="card-header">
                        <h3>Subscribers</h3>
                        <span class="growth-indicator positive">+8.2%</span>
                    </div>
                    <div class="metric-value">${this.formatNumber(this.analytics.subscribers)}</div>
                    <div class="metric-subtitle">Total subscribers</div>
                </div>

                <div class="analytics-card">
                    <div class="card-header">
                        <h3>Watch Time</h3>
                        <span class="growth-indicator positive">+15.3%</span>
                    </div>
                    <div class="metric-value">${this.formatWatchTime(this.analytics.watchTime)}</div>
                    <div class="metric-subtitle">Hours watched</div>
                </div>

                <div class="analytics-card">
                    <div class="card-header">
                        <h3>Revenue</h3>
                        <span class="growth-indicator positive">+22.1%</span>
                    </div>
                    <div class="metric-value">$${this.formatNumber(this.analytics.revenue)}</div>
                    <div class="metric-subtitle">Estimated earnings</div>
                </div>
            </div>

            <div class="charts-section">
                <div class="chart-container">
                    <h3>Views Over Time</h3>
                    <canvas id="viewsChart" width="400" height="200"></canvas>
                </div>

                <div class="chart-container">
                    <h3>Top Videos</h3>
                    <div id="topVideos" class="top-videos-list"></div>
                </div>
            </div>

            <div class="insights-section">
                <div class="insights-card">
                    <h3>Audience Demographics</h3>
                    <canvas id="demographicsChart" width="300" height="200"></canvas>
                </div>

                <div class="insights-card">
                    <h3>Traffic Sources</h3>
                    <canvas id="trafficChart" width="300" height="200"></canvas>
                </div>

                <div class="insights-card">
                    <h3>Revenue Breakdown</h3>
                    <canvas id="revenueChart" width="300" height="200"></canvas>
                </div>
            </div>

            <div class="recommendations-section">
                <h3>Recommendations</h3>
                <div class="recommendations-list">
                    <div class="recommendation-item">
                        <div class="recommendation-icon">📈</div>
                        <div class="recommendation-content">
                            <h4>Optimize Upload Schedule</h4>
                            <p>Your audience is most active on Tuesdays and Thursdays at 7 PM</p>
                        </div>
                    </div>
                    <div class="recommendation-item">
                        <div class="recommendation-icon">🎯</div>
                        <div class="recommendation-content">
                            <h4>Improve Thumbnails</h4>
                            <p>Videos with custom thumbnails get 30% more views</p>
                        </div>
                    </div>
                    <div class="recommendation-item">
                        <div class="recommendation-icon">💬</div>
                        <div class="recommendation-content">
                            <h4>Engage with Comments</h4>
                            <p>Responding to comments increases viewer retention by 25%</p>
                        </div>
                    </div>
                </div>
            </div>
        `;

        this.renderTopVideos();
    }

    // Setup charts
    setupCharts() {
        this.createViewsChart();
        this.createDemographicsChart();
        this.createTrafficChart();
        this.createRevenueChart();
    }

    // Create views over time chart
    createViewsChart() {
        const canvas = document.getElementById('viewsChart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        const data = this.generateViewsData();

        this.drawLineChart(ctx, data, {
            color: '#ff3b30',
            backgroundColor: 'rgba(255, 59, 48, 0.1)',
            title: 'Views Over Time'
        });
    }

    // Create demographics chart
    createDemographicsChart() {
        const canvas = document.getElementById('demographicsChart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        this.drawPieChart(ctx, this.analytics.demographics, 'Age Groups');
    }

    // Create traffic sources chart
    createTrafficChart() {
        const canvas = document.getElementById('trafficChart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        this.drawBarChart(ctx, this.analytics.trafficSources, 'Traffic Sources');
    }

    // Create revenue breakdown chart
    createRevenueChart() {
        const canvas = document.getElementById('revenueChart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        this.drawPieChart(ctx, this.analytics.revenueBreakdown, 'Revenue Sources');
    }

    // Draw line chart
    drawLineChart(ctx, data, options = {}) {
        const { color = '#ff3b30', backgroundColor = 'rgba(255, 59, 48, 0.1)' } = options;
        const canvas = ctx.canvas;
        const padding = 40;
        const width = canvas.width - padding * 2;
        const height = canvas.height - padding * 2;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Find min and max values
        const values = data.map(d => d.value);
        const minValue = Math.min(...values);
        const maxValue = Math.max(...values);
        const valueRange = maxValue - minValue || 1;

        // Draw grid lines
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 1;
        for (let i = 0; i <= 5; i++) {
            const y = padding + (height * i) / 5;
            ctx.beginPath();
            ctx.moveTo(padding, y);
            ctx.lineTo(padding + width, y);
            ctx.stroke();
        }

        // Draw line
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.beginPath();

        data.forEach((point, index) => {
            const x = padding + (width * index) / (data.length - 1);
            const y = padding + height - ((point.value - minValue) / valueRange) * height;

            if (index === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        });

        ctx.stroke();

        // Fill area under curve
        ctx.fillStyle = backgroundColor;
        ctx.lineTo(padding + width, padding + height);
        ctx.lineTo(padding, padding + height);
        ctx.closePath();
        ctx.fill();
    }

    // Draw pie chart
    drawPieChart(ctx, data, title) {
        const canvas = ctx.canvas;
        const centerX = canvas.width / 2;
        const centerY = canvas.height / 2;
        const radius = Math.min(centerX, centerY) - 20;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        const total = data.reduce((sum, item) => sum + item.value, 0);
        let currentAngle = -Math.PI / 2;

        const colors = ['#ff3b30', '#007aff', '#34c759', '#ff9500', '#af52de', '#ff2d92'];

        data.forEach((item, index) => {
            const sliceAngle = (item.value / total) * 2 * Math.PI;

            // Draw slice
            ctx.fillStyle = colors[index % colors.length];
            ctx.beginPath();
            ctx.moveTo(centerX, centerY);
            ctx.arc(centerX, centerY, radius, currentAngle, currentAngle + sliceAngle);
            ctx.closePath();
            ctx.fill();

            // Draw label
            const labelAngle = currentAngle + sliceAngle / 2;
            const labelX = centerX + Math.cos(labelAngle) * (radius * 0.7);
            const labelY = centerY + Math.sin(labelAngle) * (radius * 0.7);

            ctx.fillStyle = '#fff';
            ctx.font = '12px -apple-system, BlinkMacSystemFont, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(`${item.label}`, labelX, labelY);
            ctx.fillText(`${Math.round((item.value / total) * 100)}%`, labelX, labelY + 15);

            currentAngle += sliceAngle;
        });
    }

    // Draw bar chart
    drawBarChart(ctx, data, title) {
        const canvas = ctx.canvas;
        const padding = 40;
        const width = canvas.width - padding * 2;
        const height = canvas.height - padding * 2;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        const maxValue = Math.max(...data.map(d => d.value));
        const barWidth = width / data.length - 10;

        data.forEach((item, index) => {
            const barHeight = (item.value / maxValue) * height;
            const x = padding + index * (width / data.length);
            const y = padding + height - barHeight;

            // Draw bar
            ctx.fillStyle = '#ff3b30';
            ctx.fillRect(x, y, barWidth, barHeight);

            // Draw label
            ctx.fillStyle = '#fff';
            ctx.font = '10px -apple-system, BlinkMacSystemFont, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(item.label, x + barWidth / 2, padding + height + 15);
            ctx.fillText(item.value.toString(), x + barWidth / 2, y - 5);
        });
    }

    // Render top videos list
    renderTopVideos() {
        const container = document.getElementById('topVideos');
        if (!container) return;

        const topVideos = this.analytics.videos.slice(0, 5);
        
        container.innerHTML = topVideos.map((video, index) => `
            <div class="top-video-item">
                <div class="video-rank">${index + 1}</div>
                <div class="video-thumbnail">
                    <img src="${video.thumbnail}" alt="${video.title}">
                </div>
                <div class="video-info">
                    <div class="video-title">${video.title}</div>
                    <div class="video-stats">
                        <span>${this.formatNumber(video.views)} views</span>
                        <span>${video.duration}</span>
                    </div>
                </div>
                <div class="video-performance">
                    <div class="performance-metric">
                        <span class="metric-label">CTR</span>
                        <span class="metric-value">${video.ctr}%</span>
                    </div>
                    <div class="performance-metric">
                        <span class="metric-label">Retention</span>
                        <span class="metric-value">${video.retention}%</span>
                    </div>
                </div>
            </div>
        `).join('');
    }

    // Setup real-time updates
    setupRealTimeUpdates() {
        // Simulate real-time updates every 30 seconds
        setInterval(() => {
            this.updateMetrics();
        }, 30000);
    }

    // Update metrics with new data
    updateMetrics() {
        // Simulate small changes in metrics
        const viewsIncrease = Math.floor(Math.random() * 100) + 1;
        this.analytics.views += viewsIncrease;

        // Update display
        const viewsElement = document.querySelector('.analytics-card .metric-value');
        if (viewsElement) {
            viewsElement.textContent = this.formatNumber(this.analytics.views);
        }

        console.log(`📊 Analytics updated: +${viewsIncrease} views`);
    }

    // Export analytics data
    exportData() {
        const data = {
            exported: new Date().toISOString(),
            analytics: this.analytics,
            summary: {
                totalViews: this.analytics.views,
                totalSubscribers: this.analytics.subscribers,
                totalRevenue: this.analytics.revenue,
                totalWatchTime: this.analytics.watchTime
            }
        };

        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `mychannel-analytics-${new Date().toISOString().split('T')[0]}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }

    // Refresh analytics
    async refreshAnalytics() {
        if (window.performanceManager) {
            window.performanceManager.showSkeleton('creatorDashboard', 'cards');
        }

        await this.loadAnalytics();
        this.setupDashboard();
        this.setupCharts();

        console.log('📊 Analytics refreshed');
    }

    // Generate mock data
    generateMockVideoData() {
        const titles = [
            'How to Create Amazing Content',
            'Best Tips for New Creators',
            'Behind the Scenes Vlog',
            'Tutorial: Video Editing Basics',
            'Q&A with Subscribers'
        ];

        return titles.map((title, index) => ({
            id: `video_${index}`,
            title,
            views: Math.floor(Math.random() * 50000) + 10000,
            duration: `${Math.floor(Math.random() * 15) + 5}:${String(Math.floor(Math.random() * 60)).padStart(2, '0')}`,
            thumbnail: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
            ctr: (Math.random() * 5 + 3).toFixed(1),
            retention: Math.floor(Math.random() * 30 + 60)
        }));
    }

    generateViewsData() {
        const days = 30;
        const data = [];
        let baseViews = 1000;

        for (let i = 0; i < days; i++) {
            baseViews += Math.floor(Math.random() * 200) - 50;
            data.push({
                date: new Date(Date.now() - (days - i) * 24 * 60 * 60 * 1000).toLocaleDateString(),
                value: Math.max(baseViews, 500)
            });
        }

        return data;
    }

    generateDemographics() {
        return [
            { label: '18-24', value: 25 },
            { label: '25-34', value: 35 },
            { label: '35-44', value: 20 },
            { label: '45-54', value: 15 },
            { label: '55+', value: 5 }
        ];
    }

    generateTrafficSources() {
        return [
            { label: 'Browse', value: 40 },
            { label: 'Search', value: 30 },
            { label: 'Suggested', value: 20 },
            { label: 'External', value: 10 }
        ];
    }

    generateRevenueBreakdown() {
        return [
            { label: 'Ads', value: 60 },
            { label: 'Memberships', value: 25 },
            { label: 'Super Chat', value: 10 },
            { label: 'Merchandise', value: 5 }
        ];
    }

    // Utility functions
    formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return num.toString();
    }

    formatWatchTime(minutes) {
        if (minutes >= 60) {
            return (minutes / 60).toFixed(1) + 'K';
        }
        return minutes.toString();
    }
}

// Initialize creator studio
window.creatorStudio = new CreatorStudio();

// Auto-initialize when studio is opened
document.addEventListener('DOMContentLoaded', () => {
    // Initialize when studio modal is opened
    const studioModal = document.getElementById('studioModal');
    if (studioModal) {
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.type === 'attributes' && mutation.attributeName === 'style') {
                    if (studioModal.style.display === 'flex') {
                        setTimeout(() => {
                            window.creatorStudio.init();
                        }, 100);
                    }
                }
            });
        });
        observer.observe(studioModal, { attributes: true });
    }
});




