// Advanced Creator Tools for MyChannel
class CreatorToolsManager {
    constructor() {
        this.abTests = new Map();
        this.scheduledContent = [];
        this.bulkOperations = [];
        this.analytics = {
            thumbnailPerformance: new Map(),
            titlePerformance: new Map(),
            uploadTimes: new Map(),
            audienceRetention: new Map()
        };
        this.contentLibrary = [];
        this.templates = [];
        this.automationRules = [];
    }

    init() {
        this.setupABTesting();
        this.setupContentScheduling();
        this.setupBulkOperations();
        this.setupAdvancedAnalytics();
        this.setupContentTemplates();
        this.setupAutomation();
        
        console.log('🎛️ Creator Tools initialized');
    }

    // A/B Testing System
    setupABTesting() {
        this.createABTestingUI();
        this.loadActiveTests();
    }

    createABTestingUI() {
        const abTestContainer = document.createElement('div');
        abTestContainer.className = 'ab-testing-panel';
        abTestContainer.id = 'abTestingPanel';
        abTestContainer.innerHTML = `
            <div class="panel-header">
                <h3>A/B Testing</h3>
                <button class="btn btn-primary btn-sm" onclick="creatorTools.createNewABTest()">
                    New Test
                </button>
            </div>
            
            <div class="active-tests" id="activeTests">
                <div class="empty-state">
                    <div class="empty-icon">🧪</div>
                    <p>No active A/B tests</p>
                    <small>Test thumbnails, titles, and descriptions to optimize performance</small>
                </div>
            </div>
            
            <div class="test-results" id="testResults">
                <h4>Recent Test Results</h4>
                <div id="completedTests"></div>
            </div>
        `;
        
        // Add to creator studio
        const studioContent = document.getElementById('studioModal');
        if (studioContent) {
            studioContent.appendChild(abTestContainer);
        }
    }

    createNewABTest() {
        const modal = document.createElement('div');
        modal.className = 'ab-test-modal';
        modal.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()">
                <div class="modal-content" onclick="event.stopPropagation()">
                    <h3>Create A/B Test</h3>
                    
                    <div class="form-group">
                        <label>Test Type</label>
                        <select id="testType" class="form-input">
                            <option value="thumbnail">Thumbnail</option>
                            <option value="title">Title</option>
                            <option value="description">Description</option>
                            <option value="upload_time">Upload Time</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label>Video</label>
                        <select id="testVideo" class="form-input">
                            <option value="">Select video...</option>
                            ${this.getVideoOptions()}
                        </select>
                    </div>
                    
                    <div class="variants-section">
                        <h4>Variants</h4>
                        <div id="variantA" class="variant-input">
                            <label>Variant A (Control)</label>
                            <div class="variant-content" id="variantAContent"></div>
                        </div>
                        <div id="variantB" class="variant-input">
                            <label>Variant B (Test)</label>
                            <div class="variant-content" id="variantBContent"></div>
                        </div>
                    </div>
                    
                    <div class="test-settings">
                        <div class="form-group">
                            <label>Traffic Split</label>
                            <div class="split-slider">
                                <input type="range" id="trafficSplit" min="10" max="90" value="50">
                                <div class="split-labels">
                                    <span id="splitA">50%</span>
                                    <span id="splitB">50%</span>
                                </div>
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label>Test Duration</label>
                            <select id="testDuration" class="form-input">
                                <option value="7">7 days</option>
                                <option value="14">14 days</option>
                                <option value="30">30 days</option>
                                <option value="custom">Custom</option>
                            </select>
                        </div>
                        
                        <div class="form-group">
                            <label>Success Metric</label>
                            <select id="successMetric" class="form-input">
                                <option value="ctr">Click-through Rate</option>
                                <option value="views">Total Views</option>
                                <option value="watch_time">Watch Time</option>
                                <option value="engagement">Engagement Rate</option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="modal-actions">
                        <button class="btn btn-secondary" onclick="this.closest('.ab-test-modal').remove()">
                            Cancel
                        </button>
                        <button class="btn btn-primary" onclick="creatorTools.startABTest()">
                            Start Test
                        </button>
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
        this.setupABTestForm();
    }

    setupABTestForm() {
        const testType = document.getElementById('testType');
        const trafficSplit = document.getElementById('trafficSplit');
        
        testType?.addEventListener('change', (e) => {
            this.updateVariantInputs(e.target.value);
        });
        
        trafficSplit?.addEventListener('input', (e) => {
            const value = parseInt(e.target.value);
            document.getElementById('splitA').textContent = `${value}%`;
            document.getElementById('splitB').textContent = `${100 - value}%`;
        });
        
        // Initialize with thumbnail test
        this.updateVariantInputs('thumbnail');
    }

    updateVariantInputs(testType) {
        const variantAContent = document.getElementById('variantAContent');
        const variantBContent = document.getElementById('variantBContent');
        
        if (!variantAContent || !variantBContent) return;
        
        switch (testType) {
            case 'thumbnail':
                variantAContent.innerHTML = `
                    <input type="file" accept="image/*" class="form-input" placeholder="Upload thumbnail A">
                    <div class="thumbnail-preview" id="thumbnailPreviewA"></div>
                `;
                variantBContent.innerHTML = `
                    <input type="file" accept="image/*" class="form-input" placeholder="Upload thumbnail B">
                    <div class="thumbnail-preview" id="thumbnailPreviewB"></div>
                `;
                break;
            case 'title':
                variantAContent.innerHTML = `<input type="text" class="form-input" placeholder="Title variant A" maxlength="100">`;
                variantBContent.innerHTML = `<input type="text" class="form-input" placeholder="Title variant B" maxlength="100">`;
                break;
            case 'description':
                variantAContent.innerHTML = `<textarea class="form-input" placeholder="Description variant A" rows="4"></textarea>`;
                variantBContent.innerHTML = `<textarea class="form-input" placeholder="Description variant B" rows="4"></textarea>`;
                break;
            case 'upload_time':
                variantAContent.innerHTML = `<input type="datetime-local" class="form-input">`;
                variantBContent.innerHTML = `<input type="datetime-local" class="form-input">`;
                break;
        }
    }

    startABTest() {
        const testData = this.collectABTestData();
        if (!testData) return;
        
        const testId = this.generateTestId();
        const test = {
            id: testId,
            type: testData.type,
            videoId: testData.videoId,
            variants: testData.variants,
            settings: testData.settings,
            status: 'running',
            startDate: new Date(),
            endDate: new Date(Date.now() + testData.settings.duration * 24 * 60 * 60 * 1000),
            results: {
                variantA: { views: 0, clicks: 0, engagement: 0 },
                variantB: { views: 0, clicks: 0, engagement: 0 }
            }
        };
        
        this.abTests.set(testId, test);
        this.saveABTests();
        this.renderActiveTests();
        
        // Close modal
        document.querySelector('.ab-test-modal')?.remove();
        
        this.showNotification(`A/B test "${test.type}" started successfully!`, 'success');
    }

    // Content Scheduling System
    setupContentScheduling() {
        this.createSchedulingUI();
        this.loadScheduledContent();
        this.startScheduleChecker();
    }

    createSchedulingUI() {
        const schedulerContainer = document.createElement('div');
        schedulerContainer.className = 'content-scheduler';
        schedulerContainer.id = 'contentScheduler';
        schedulerContainer.innerHTML = `
            <div class="panel-header">
                <h3>Content Scheduler</h3>
                <button class="btn btn-primary btn-sm" onclick="creatorTools.scheduleContent()">
                    Schedule Content
                </button>
            </div>
            
            <div class="scheduler-calendar" id="schedulerCalendar">
                <div class="calendar-header">
                    <button onclick="creatorTools.previousMonth()">&lt;</button>
                    <h4 id="currentMonth"></h4>
                    <button onclick="creatorTools.nextMonth()">&gt;</button>
                </div>
                <div class="calendar-grid" id="calendarGrid"></div>
            </div>
            
            <div class="scheduled-items" id="scheduledItems">
                <h4>Upcoming Uploads</h4>
                <div id="upcomingList"></div>
            </div>
        `;
        
        const studioContent = document.getElementById('studioModal');
        if (studioContent) {
            studioContent.appendChild(schedulerContainer);
        }
        
        this.renderCalendar();
    }

    renderCalendar() {
        const now = new Date();
        const currentMonth = document.getElementById('currentMonth');
        const calendarGrid = document.getElementById('calendarGrid');
        
        if (currentMonth) {
            currentMonth.textContent = now.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
        }
        
        if (calendarGrid) {
            // Generate calendar days with scheduled content indicators
            const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
            let calendarHTML = '<div class="calendar-days">';
            
            ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].forEach(day => {
                calendarHTML += `<div class="calendar-day-header">${day}</div>`;
            });
            
            for (let day = 1; day <= daysInMonth; day++) {
                const date = new Date(now.getFullYear(), now.getMonth(), day);
                const hasScheduled = this.scheduledContent.some(item => 
                    new Date(item.scheduledDate).toDateString() === date.toDateString()
                );
                
                calendarHTML += `
                    <div class="calendar-day ${hasScheduled ? 'has-scheduled' : ''}" 
                         onclick="creatorTools.selectDate('${date.toISOString()}')">
                        ${day}
                        ${hasScheduled ? '<div class="scheduled-indicator"></div>' : ''}
                    </div>
                `;
            }
            
            calendarHTML += '</div>';
            calendarGrid.innerHTML = calendarHTML;
        }
    }

    scheduleContent() {
        const modal = document.createElement('div');
        modal.className = 'schedule-modal';
        modal.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()">
                <div class="modal-content" onclick="event.stopPropagation()">
                    <h3>Schedule Content</h3>
                    
                    <div class="form-group">
                        <label>Content Type</label>
                        <select id="contentType" class="form-input">
                            <option value="video">Video</option>
                            <option value="short">Short</option>
                            <option value="live">Live Stream</option>
                            <option value="post">Community Post</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label>Title</label>
                        <input type="text" id="contentTitle" class="form-input" placeholder="Content title">
                    </div>
                    
                    <div class="form-group">
                        <label>Description</label>
                        <textarea id="contentDescription" class="form-input" rows="3" placeholder="Content description"></textarea>
                    </div>
                    
                    <div class="form-group">
                        <label>Scheduled Date & Time</label>
                        <input type="datetime-local" id="scheduledDateTime" class="form-input">
                    </div>
                    
                    <div class="form-group">
                        <label>Tags</label>
                        <input type="text" id="contentTags" class="form-input" placeholder="Comma-separated tags">
                    </div>
                    
                    <div class="form-group">
                        <label>
                            <input type="checkbox" id="autoPublish"> Auto-publish when scheduled time arrives
                        </label>
                    </div>
                    
                    <div class="modal-actions">
                        <button class="btn btn-secondary" onclick="this.closest('.schedule-modal').remove()">
                            Cancel
                        </button>
                        <button class="btn btn-primary" onclick="creatorTools.saveScheduledContent()">
                            Schedule
                        </button>
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
        
        // Set default date to tomorrow
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(12, 0, 0, 0);
        document.getElementById('scheduledDateTime').value = tomorrow.toISOString().slice(0, 16);
    }

    saveScheduledContent() {
        const contentData = {
            id: this.generateId(),
            type: document.getElementById('contentType')?.value,
            title: document.getElementById('contentTitle')?.value,
            description: document.getElementById('contentDescription')?.value,
            scheduledDate: document.getElementById('scheduledDateTime')?.value,
            tags: document.getElementById('contentTags')?.value.split(',').map(t => t.trim()),
            autoPublish: document.getElementById('autoPublish')?.checked,
            status: 'scheduled',
            createdAt: new Date().toISOString()
        };
        
        if (!contentData.title || !contentData.scheduledDate) {
            this.showNotification('Please fill in required fields', 'error');
            return;
        }
        
        this.scheduledContent.push(contentData);
        this.saveScheduledContent();
        this.renderCalendar();
        this.renderUpcomingContent();
        
        document.querySelector('.schedule-modal')?.remove();
        this.showNotification('Content scheduled successfully!', 'success');
    }

    // Bulk Operations
    setupBulkOperations() {
        this.createBulkOperationsUI();
    }

    createBulkOperationsUI() {
        const bulkContainer = document.createElement('div');
        bulkContainer.className = 'bulk-operations';
        bulkContainer.id = 'bulkOperations';
        bulkContainer.innerHTML = `
            <div class="panel-header">
                <h3>Bulk Operations</h3>
                <div class="bulk-actions">
                    <select id="bulkAction" class="form-input">
                        <option value="">Select action...</option>
                        <option value="update_tags">Update Tags</option>
                        <option value="change_privacy">Change Privacy</option>
                        <option value="update_thumbnails">Update Thumbnails</option>
                        <option value="add_to_playlist">Add to Playlist</option>
                        <option value="update_descriptions">Update Descriptions</option>
                    </select>
                    <button class="btn btn-primary btn-sm" onclick="creatorTools.executeBulkOperation()">
                        Apply
                    </button>
                </div>
            </div>
            
            <div class="video-selection">
                <div class="selection-controls">
                    <button onclick="creatorTools.selectAllVideos()">Select All</button>
                    <button onclick="creatorTools.clearSelection()">Clear Selection</button>
                    <span class="selection-count" id="selectionCount">0 selected</span>
                </div>
                
                <div class="video-list" id="bulkVideoList">
                    ${this.renderVideoSelectionList()}
                </div>
            </div>
        `;
        
        const studioContent = document.getElementById('studioModal');
        if (studioContent) {
            studioContent.appendChild(bulkContainer);
        }
    }

    renderVideoSelectionList() {
        // Mock video list - in real app, this would come from API
        const mockVideos = [
            { id: '1', title: 'Sample Video 1', views: 1234, status: 'public' },
            { id: '2', title: 'Sample Video 2', views: 5678, status: 'unlisted' },
            { id: '3', title: 'Sample Video 3', views: 9012, status: 'private' }
        ];
        
        return mockVideos.map(video => `
            <div class="video-item">
                <label class="video-checkbox">
                    <input type="checkbox" value="${video.id}" onchange="creatorTools.updateSelectionCount()">
                    <div class="video-info">
                        <h4>${video.title}</h4>
                        <div class="video-meta">
                            <span>${video.views.toLocaleString()} views</span>
                            <span class="status-${video.status}">${video.status}</span>
                        </div>
                    </div>
                </label>
            </div>
        `).join('');
    }

    updateSelectionCount() {
        const selected = document.querySelectorAll('#bulkVideoList input[type="checkbox"]:checked');
        const count = document.getElementById('selectionCount');
        if (count) {
            count.textContent = `${selected.length} selected`;
        }
    }

    selectAllVideos() {
        document.querySelectorAll('#bulkVideoList input[type="checkbox"]').forEach(cb => {
            cb.checked = true;
        });
        this.updateSelectionCount();
    }

    clearSelection() {
        document.querySelectorAll('#bulkVideoList input[type="checkbox"]').forEach(cb => {
            cb.checked = false;
        });
        this.updateSelectionCount();
    }

    executeBulkOperation() {
        const action = document.getElementById('bulkAction')?.value;
        const selected = Array.from(document.querySelectorAll('#bulkVideoList input[type="checkbox"]:checked'))
            .map(cb => cb.value);
        
        if (!action || selected.length === 0) {
            this.showNotification('Please select an action and videos', 'error');
            return;
        }
        
        // Execute the bulk operation
        this.performBulkOperation(action, selected);
    }

    performBulkOperation(action, videoIds) {
        // Mock implementation - in real app, this would call API
        const operation = {
            id: this.generateId(),
            action,
            videoIds,
            status: 'processing',
            startTime: new Date(),
            progress: 0
        };
        
        this.bulkOperations.push(operation);
        this.showBulkOperationProgress(operation);
        
        // Simulate processing
        this.simulateBulkOperation(operation);
    }

    simulateBulkOperation(operation) {
        let progress = 0;
        const interval = setInterval(() => {
            progress += Math.random() * 20;
            operation.progress = Math.min(progress, 100);
            
            this.updateBulkOperationProgress(operation);
            
            if (operation.progress >= 100) {
                clearInterval(interval);
                operation.status = 'completed';
                operation.endTime = new Date();
                this.showNotification(`Bulk operation completed for ${operation.videoIds.length} videos`, 'success');
            }
        }, 500);
    }

    // Advanced Analytics
    setupAdvancedAnalytics() {
        this.createAdvancedAnalyticsUI();
        this.loadAnalyticsData();
    }

    createAdvancedAnalyticsUI() {
        const analyticsContainer = document.createElement('div');
        analyticsContainer.className = 'advanced-analytics';
        analyticsContainer.id = 'advancedAnalytics';
        analyticsContainer.innerHTML = `
            <div class="panel-header">
                <h3>Advanced Analytics</h3>
                <div class="analytics-filters">
                    <select id="analyticsTimeframe" class="form-input">
                        <option value="7">Last 7 days</option>
                        <option value="30">Last 30 days</option>
                        <option value="90">Last 90 days</option>
                        <option value="365">Last year</option>
                    </select>
                </div>
            </div>
            
            <div class="analytics-tabs">
                <button class="analytics-tab active" onclick="creatorTools.showAnalyticsTab('performance')">
                    Performance
                </button>
                <button class="analytics-tab" onclick="creatorTools.showAnalyticsTab('audience')">
                    Audience
                </button>
                <button class="analytics-tab" onclick="creatorTools.showAnalyticsTab('optimization')">
                    Optimization
                </button>
            </div>
            
            <div class="analytics-content">
                <div id="performanceAnalytics" class="analytics-panel active">
                    <div class="metric-cards">
                        <div class="metric-card">
                            <h4>Avg. Click-through Rate</h4>
                            <div class="metric-value">8.2%</div>
                            <div class="metric-change positive">+1.3%</div>
                        </div>
                        <div class="metric-card">
                            <h4>Avg. View Duration</h4>
                            <div class="metric-value">4:32</div>
                            <div class="metric-change positive">+12s</div>
                        </div>
                        <div class="metric-card">
                            <h4>Engagement Rate</h4>
                            <div class="metric-value">12.5%</div>
                            <div class="metric-change negative">-0.8%</div>
                        </div>
                    </div>
                    <div class="chart-container">
                        <canvas id="performanceChart"></canvas>
                    </div>
                </div>
                
                <div id="audienceAnalytics" class="analytics-panel">
                    <div class="audience-insights">
                        <h4>Top Performing Content Types</h4>
                        <div class="content-type-chart"></div>
                    </div>
                </div>
                
                <div id="optimizationAnalytics" class="analytics-panel">
                    <div class="optimization-suggestions">
                        <h4>Optimization Recommendations</h4>
                        <div class="suggestions-list" id="optimizationSuggestions"></div>
                    </div>
                </div>
            </div>
        `;
        
        const studioContent = document.getElementById('studioModal');
        if (studioContent) {
            studioContent.appendChild(analyticsContainer);
        }
    }

    showAnalyticsTab(tabName) {
        // Hide all panels
        document.querySelectorAll('.analytics-panel').forEach(panel => {
            panel.classList.remove('active');
        });
        
        // Hide all tab buttons
        document.querySelectorAll('.analytics-tab').forEach(tab => {
            tab.classList.remove('active');
        });
        
        // Show selected panel and tab
        document.getElementById(`${tabName}Analytics`)?.classList.add('active');
        event.target.classList.add('active');
    }

    // Utility Functions
    generateId() {
        return 'id_' + Math.random().toString(36).substr(2, 9);
    }

    generateTestId() {
        return 'test_' + Math.random().toString(36).substr(2, 9);
    }

    getVideoOptions() {
        // Mock video options - in real app, this would come from API
        return `
            <option value="video1">Sample Video 1</option>
            <option value="video2">Sample Video 2</option>
            <option value="video3">Sample Video 3</option>
        `;
    }

    collectABTestData() {
        const type = document.getElementById('testType')?.value;
        const videoId = document.getElementById('testVideo')?.value;
        const trafficSplit = parseInt(document.getElementById('trafficSplit')?.value || '50');
        const duration = parseInt(document.getElementById('testDuration')?.value || '7');
        const metric = document.getElementById('successMetric')?.value;
        
        if (!type || !videoId) {
            this.showNotification('Please fill in all required fields', 'error');
            return null;
        }
        
        return {
            type,
            videoId,
            variants: {
                A: this.getVariantData('variantAContent'),
                B: this.getVariantData('variantBContent')
            },
            settings: {
                trafficSplit,
                duration,
                successMetric: metric
            }
        };
    }

    getVariantData(containerId) {
        const container = document.getElementById(containerId);
        const input = container?.querySelector('input, textarea');
        return input?.value || '';
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.classList.add('show');
        }, 100);
        
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }

    saveABTests() {
        localStorage.setItem('abTests', JSON.stringify(Array.from(this.abTests.entries())));
    }

    loadABTests() {
        const saved = localStorage.getItem('abTests');
        if (saved) {
            this.abTests = new Map(JSON.parse(saved));
        }
    }

    saveScheduledContent() {
        localStorage.setItem('scheduledContent', JSON.stringify(this.scheduledContent));
    }

    loadScheduledContent() {
        const saved = localStorage.getItem('scheduledContent');
        if (saved) {
            this.scheduledContent = JSON.parse(saved);
        }
    }

    startScheduleChecker() {
        // Check every minute for scheduled content
        setInterval(() => {
            this.checkScheduledContent();
        }, 60000);
    }

    checkScheduledContent() {
        const now = new Date();
        this.scheduledContent.forEach(item => {
            if (item.status === 'scheduled' && new Date(item.scheduledDate) <= now) {
                if (item.autoPublish) {
                    this.publishScheduledContent(item);
                } else {
                    this.notifyScheduledContent(item);
                }
            }
        });
    }

    publishScheduledContent(item) {
        // Mock publishing - in real app, this would call API
        item.status = 'published';
        item.publishedAt = new Date().toISOString();
        
        this.showNotification(`"${item.title}" has been published!`, 'success');
        this.saveScheduledContent();
    }

    notifyScheduledContent(item) {
        item.status = 'ready';
        this.showNotification(`"${item.title}" is ready to publish!`, 'info');
        this.saveScheduledContent();
    }
}

// Initialize creator tools
const creatorTools = new CreatorToolsManager();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => creatorTools.init());
} else {
    creatorTools.init();
}








