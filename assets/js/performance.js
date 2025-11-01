// MyChannel Performance Utilities
class PerformanceManager {
    constructor() {
        this.loadingStates = new Map();
        this.retryAttempts = new Map();
        this.maxRetries = 3;
    }

    // Show loading skeleton for a section
    showSkeleton(containerId, type = 'cards') {
        const container = document.getElementById(containerId);
        if (!container) return;

        this.loadingStates.set(containerId, true);
        
        let skeletonHTML = '';
        switch (type) {
            case 'cards':
                skeletonHTML = this.generateCardSkeletons(5);
                break;
            case 'chips':
                skeletonHTML = this.generateChipSkeletons(8);
                break;
            case 'list':
                skeletonHTML = this.generateListSkeletons(6);
                break;
        }
        
        container.innerHTML = skeletonHTML;
    }

    // Hide loading skeleton and show content
    hideSkeleton(containerId) {
        this.loadingStates.set(containerId, false);
    }

    // Generate card skeletons
    generateCardSkeletons(count) {
        const skeleton = `
            <div class="video-card" style="width:320px; flex:0 0 320px;">
                <div class="skeleton skeleton-card"></div>
                <div style="padding:12px;">
                    <div class="skeleton skeleton-title"></div>
                    <div class="skeleton skeleton-text" style="width:60%;"></div>
                </div>
            </div>
        `;
        return skeleton.repeat(count);
    }

    // Generate chip skeletons
    generateChipSkeletons(count) {
        const skeleton = `
            <div style="display:flex; align-items:center; gap:8px; padding:8px 12px; background:var(--bg-secondary); border-radius:20px; white-space:nowrap;">
                <div class="skeleton" style="width:32px; height:32px; border-radius:50%;"></div>
                <div class="skeleton skeleton-text" style="width:80px;"></div>
            </div>
        `;
        return `<div style="display:flex; gap:8px; overflow-x:auto; padding:8px 0;">${skeleton.repeat(count)}</div>`;
    }

    // Generate list skeletons
    generateListSkeletons(count) {
        const skeleton = `
            <div style="display:flex; align-items:center; gap:12px; padding:12px 0; border-bottom:1px solid var(--border);">
                <div class="skeleton" style="width:60px; height:60px; border-radius:8px;"></div>
                <div style="flex:1;">
                    <div class="skeleton skeleton-title" style="margin-bottom:8px;"></div>
                    <div class="skeleton skeleton-text" style="width:40%;"></div>
                </div>
            </div>
        `;
        return skeleton.repeat(count);
    }

    // Show error state with retry
    showError(containerId, message = 'Failed to load content', retryCallback = null) {
        const container = document.getElementById(containerId);
        if (!container) return;

        const errorHTML = `
            <div class="error-message">
                <div style="font-size:24px; margin-bottom:8px;">⚠️</div>
                <div style="font-weight:600; margin-bottom:4px;">Oops! Something went wrong</div>
                <div style="opacity:0.8; font-size:14px; margin-bottom:12px;">${message}</div>
                ${retryCallback ? '<button class="retry-button" onclick="' + retryCallback + '">Try Again</button>' : ''}
            </div>
        `;
        
        container.innerHTML = errorHTML;
    }

    // Retry mechanism with exponential backoff
    async retryOperation(operationName, operation, maxRetries = this.maxRetries) {
        const currentAttempts = this.retryAttempts.get(operationName) || 0;
        
        if (currentAttempts >= maxRetries) {
            throw new Error(`Max retries exceeded for ${operationName}`);
        }

        try {
            const result = await operation();
            this.retryAttempts.delete(operationName);
            return result;
        } catch (error) {
            const newAttempts = currentAttempts + 1;
            this.retryAttempts.set(operationName, newAttempts);
            
            // Exponential backoff: 1s, 2s, 4s
            const delay = Math.pow(2, currentAttempts) * 1000;
            await new Promise(resolve => setTimeout(resolve, delay));
            
            return this.retryOperation(operationName, operation, maxRetries);
        }
    }

    // Lazy load images with intersection observer
    initLazyLoading() {
        if ('IntersectionObserver' in window) {
            const imageObserver = new IntersectionObserver((entries, observer) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        if (img.dataset.src) {
                            img.src = img.dataset.src;
                            img.removeAttribute('data-src');
                            img.classList.remove('lazy');
                            observer.unobserve(img);
                        }
                    }
                });
            });

            document.querySelectorAll('img[data-src]').forEach(img => {
                imageObserver.observe(img);
            });
        } else {
            // Fallback for older browsers
            document.querySelectorAll('img[data-src]').forEach(img => {
                img.src = img.dataset.src;
                img.removeAttribute('data-src');
            });
        }
    }

    // Preload critical resources
    preloadCriticalResources() {
        const criticalImages = [
            '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
            '/assets/UserProfileAvatar.imageset/UserProfileAvatar.PNG'
        ];

        criticalImages.forEach(src => {
            const link = document.createElement('link');
            link.rel = 'preload';
            link.as = 'image';
            link.href = src;
            document.head.appendChild(link);
        });
    }

    // Monitor performance metrics
    trackPerformance() {
        if ('performance' in window) {
            window.addEventListener('load', () => {
                setTimeout(() => {
                    const perfData = performance.getEntriesByType('navigation')[0];
                    const metrics = {
                        loadTime: Math.round(perfData.loadEventEnd - perfData.fetchStart),
                        domContentLoaded: Math.round(perfData.domContentLoadedEventEnd - perfData.fetchStart),
                        firstPaint: 0,
                        firstContentfulPaint: 0
                    };

                    // Get paint metrics if available
                    const paintEntries = performance.getEntriesByType('paint');
                    paintEntries.forEach(entry => {
                        if (entry.name === 'first-paint') {
                            metrics.firstPaint = Math.round(entry.startTime);
                        } else if (entry.name === 'first-contentful-paint') {
                            metrics.firstContentfulPaint = Math.round(entry.startTime);
                        }
                    });

                    console.log('📊 Performance Metrics:', metrics);
                    
                    // Track to analytics if available
                    if (window.myChannelAPI?.trackEvent) {
                        window.myChannelAPI.trackEvent('performance_metrics', metrics);
                    }
                }, 0);
            });
        }
    }

    // Debounce function for search and other inputs
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

    // Throttle function for scroll events
    throttle(func, limit) {
        let inThrottle;
        return function() {
            const args = arguments;
            const context = this;
            if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        }
    }
}

// Global performance manager instance
window.performanceManager = new PerformanceManager();

// Auto-initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
    window.performanceManager.preloadCriticalResources();
    window.performanceManager.trackPerformance();
    
    // Initialize lazy loading after a short delay
    setTimeout(() => {
        window.performanceManager.initLazyLoading();
    }, 100);
});









