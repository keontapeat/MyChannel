// 🔥 THERMONUCLEAR: Performance Monitor for Web
// Real-time performance tracking (mirrors iOS PerformanceMonitor)

interface PerformanceMetrics {
  avgImageLoadTime: number;
  avgNetworkRequestTime: number;
  avgPageLoadTime: number;
  cacheHitRate: number;
  currentFPS: number;
  memoryUsageMB: number;
  
  totalImageLoads: number;
  totalNetworkRequests: number;
  slowImageLoads: number;
  slowNetworkRequests: number;
}

class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  
  private imageLoadTimes: number[] = [];
  private networkRequestTimes: number[] = [];
  private cacheHits = 0;
  private cacheMisses = 0;
  
  metrics: PerformanceMetrics = {
    avgImageLoadTime: 0,
    avgNetworkRequestTime: 0,
    avgPageLoadTime: 0,
    cacheHitRate: 0,
    currentFPS: 60,
    memoryUsageMB: 0,
    totalImageLoads: 0,
    totalNetworkRequests: 0,
    slowImageLoads: 0,
    slowNetworkRequests: 0,
  };

  private constructor() {
    this.startMonitoring();
    console.log('⚡ [PerformanceMonitor] Started - tracking all metrics');
  }

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  /**
   * 🔥 Track image load time
   */
  measureImageLoad(duration: number, fromCache: boolean): void {
    this.imageLoadTimes.push(duration);
    
    if (fromCache) {
      this.cacheHits++;
    } else {
      this.cacheMisses++;
    }
    
    // Keep last 100 measurements
    if (this.imageLoadTimes.length > 100) {
      this.imageLoadTimes.shift();
    }
    
    // Alert if slow (>200ms)
    if (duration > 200) {
      this.metrics.slowImageLoads++;
      console.warn(`🐌 [Performance] Slow image load: ${duration.toFixed(0)}ms`);
    }
    
    this.metrics.totalImageLoads++;
    this.updateMetrics();
  }

  /**
   * 🔥 Track network request time
   */
  measureNetworkRequest(url: string, duration: number, fromCache: boolean = false): void {
    this.networkRequestTimes.push(duration);
    
    if (fromCache) {
      this.cacheHits++;
    } else {
      this.cacheMisses++;
    }
    
    if (this.networkRequestTimes.length > 100) {
      this.networkRequestTimes.shift();
    }
    
    // Alert if slow (>500ms)
    if (duration > 500) {
      this.metrics.slowNetworkRequests++;
      console.warn(`🐌 [Performance] Slow network: ${url} - ${duration.toFixed(0)}ms`);
    }
    
    this.metrics.totalNetworkRequests++;
    this.updateMetrics();
  }

  /**
   * Update metrics
   */
  private updateMetrics(): void {
    // Calculate averages
    const avgImageLoad = this.imageLoadTimes.length > 0
      ? this.imageLoadTimes.reduce((a, b) => a + b, 0) / this.imageLoadTimes.length
      : 0;
    
    const avgNetwork = this.networkRequestTimes.length > 0
      ? this.networkRequestTimes.reduce((a, b) => a + b, 0) / this.networkRequestTimes.length
      : 0;
    
    // Calculate cache hit rate
    const total = this.cacheHits + this.cacheMisses;
    const hitRate = total > 0 ? this.cacheHits / total : 0;
    
    // Get memory usage (if available)
    const memory = (performance as any).memory
      ? (performance as any).memory.usedJSHeapSize / 1_000_000
      : 0;
    
    this.metrics = {
      ...this.metrics,
      avgImageLoadTime: avgImageLoad,
      avgNetworkRequestTime: avgNetwork,
      cacheHitRate: hitRate,
      memoryUsageMB: Math.round(memory),
    };
  }

  /**
   * Start monitoring
   */
  private startMonitoring(): void {
    // Update metrics every 5 seconds
    setInterval(() => {
      this.updateMetrics();
      
      // Log summary every 50 image loads
      if (this.metrics.totalImageLoads % 50 === 0 && this.metrics.totalImageLoads > 0) {
        this.printReport();
      }
    }, 5000);
    
    // Track FPS (if available)
    if (typeof requestAnimationFrame !== 'undefined') {
      this.trackFPS();
    }
  }

  /**
   * Track FPS
   */
  private trackFPS(): void {
    let lastTime = performance.now();
    let frames = 0;
    
    const measureFPS = () => {
      frames++;
      const now = performance.now();
      
      if (now >= lastTime + 1000) {
        this.metrics.currentFPS = Math.round(frames * 1000 / (now - lastTime));
        frames = 0;
        lastTime = now;
      }
      
      requestAnimationFrame(measureFPS);
    };
    
    requestAnimationFrame(measureFPS);
  }

  /**
   * Get performance report
   */
  getReport(): string {
    return `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 PERFORMANCE METRICS (WEB)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Avg Image Load:    ${this.metrics.avgImageLoadTime.toFixed(0)}ms
Avg Network:       ${this.metrics.avgNetworkRequestTime.toFixed(0)}ms
Cache Hit Rate:    ${(this.metrics.cacheHitRate * 100).toFixed(0)}%
Current FPS:       ${this.metrics.currentFPS}fps
Memory Usage:      ${this.metrics.memoryUsageMB}MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Images:      ${this.metrics.totalImageLoads} (${this.metrics.slowImageLoads} slow)
Total Network:     ${this.metrics.totalNetworkRequests} (${this.metrics.slowNetworkRequests} slow)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    `.trim();
  }

  /**
   * Print report to console
   */
  printReport(): void {
    console.log(this.getReport());
  }

  /**
   * Reset metrics
   */
  reset(): void {
    this.imageLoadTimes = [];
    this.networkRequestTimes = [];
    this.cacheHits = 0;
    this.cacheMisses = 0;
    this.metrics = {
      avgImageLoadTime: 0,
      avgNetworkRequestTime: 0,
      avgPageLoadTime: 0,
      cacheHitRate: 0,
      currentFPS: 60,
      memoryUsageMB: 0,
      totalImageLoads: 0,
      totalNetworkRequests: 0,
      slowImageLoads: 0,
      slowNetworkRequests: 0,
    };
  }
}

export const performanceMonitor = PerformanceMonitor.getInstance();

