// 🔥 THERMONUCLEAR: Image Prefetcher for Web
// Mirrors iOS ImagePrefetcher with 12-ahead prefetch + viewport optimization

class ImagePrefetcher {
  private static instance: ImagePrefetcher;
  private prefetchQueue: Set<string> = new Set();
  private maxConcurrent = 6; // Web can handle more concurrent
  private activePrefetches = 0;

  private constructor() {
    console.log('⚡ [ImagePrefetcher] Initialized - 12 ahead + viewport prefetch');
  }

  static getInstance(): ImagePrefetcher {
    if (!ImagePrefetcher.instance) {
      ImagePrefetcher.instance = new ImagePrefetcher();
    }
    return ImagePrefetcher.instance;
  }

  /**
   * 🔥 THERMONUCLEAR: Prefetch single image
   */
  prefetch(url: string): void {
    if (this.prefetchQueue.has(url)) return;
    if (this.activePrefetches >= this.maxConcurrent) return;

    this.prefetchQueue.add(url);
    this.activePrefetches++;

    const img = new Image();
    img.onload = () => {
      this.activePrefetches--;
      console.log(`✅ [Prefetch] Loaded: ${url.substring(url.lastIndexOf('/') + 1)}`);
      this.processQueue();
    };
    img.onerror = () => {
      this.activePrefetches--;
      this.processQueue();
    };
    img.src = url;
  }

  /**
   * 🔥 THERMONUCLEAR: Prefetch 12 images ahead
   */
  prefetchMultiple(urls: string[]): void {
    // Prefetch first 12 for ultra-fast scrolling
    urls.slice(0, 12).forEach(url => this.prefetch(url));
  }

  /**
   * 🔥 NEW: Viewport-based prefetching
   * Prefetch visible + next 24 items (2 screens ahead)
   */
  prefetchViewport(urls: string[], visibleRange: { start: number; end: number }): void {
    const prefetchEnd = Math.min(urls.length, visibleRange.end + 24);
    const urlsToPrefetch = urls.slice(visibleRange.start, prefetchEnd);
    
    urlsToPrefetch.forEach(url => this.prefetch(url));
    
    console.log(`⚡ [Prefetch] Viewport: ${urlsToPrefetch.length} images queued`);
  }

  /**
   * Process prefetch queue
   */
  private processQueue(): void {
    // Try to prefetch more if under limit
    if (this.activePrefetches < this.maxConcurrent && this.prefetchQueue.size > 0) {
      const nextUrl = Array.from(this.prefetchQueue).find(url => {
        // Find URL not currently being fetched
        return true; // Simplified for now
      });
      
      if (nextUrl) {
        this.prefetch(nextUrl);
      }
    }
  }

  /**
   * Clear all prefetches
   */
  clear(): void {
    this.prefetchQueue.clear();
    this.activePrefetches = 0;
  }
}

export const imagePrefetcher = ImagePrefetcher.getInstance();

