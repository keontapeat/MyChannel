/**
 * Web Vitals Performance Tracker
 * Monitors Core Web Vitals for Lighthouse optimization
 */

import { onCLS, onFCP, onFID, onLCP, onTTFB, Metric } from 'web-vitals';

interface WebVitalsReport {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  delta: number;
  id: string;
}

class WebVitalsTracker {
  private metrics: Map<string, WebVitalsReport> = new Map();

  constructor() {
    this.initializeTracking();
  }

  private initializeTracking() {
    // Largest Contentful Paint (LCP)
    onLCP(this.handleMetric.bind(this), { reportAllChanges: true });

    // First Input Delay (FID)
    onFID(this.handleMetric.bind(this), { reportAllChanges: true });

    // Cumulative Layout Shift (CLS)
    onCLS(this.handleMetric.bind(this), { reportAllChanges: true });

    // First Contentful Paint (FCP)
    onFCP(this.handleMetric.bind(this), { reportAllChanges: true });

    // Time to First Byte (TTFB)
    onTTFB(this.handleMetric.bind(this), { reportAllChanges: true });

    console.log('📊 Web Vitals tracking initialized');
  }

  private handleMetric(metric: Metric) {
    const rating = this.getRating(metric);
    
    const report: WebVitalsReport = {
      name: metric.name,
      value: metric.value,
      rating,
      delta: metric.delta,
      id: metric.id,
    };

    this.metrics.set(metric.name, report);

    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`📊 [${metric.name}] ${metric.value.toFixed(2)}ms - ${rating}`);
    }

    // Send to analytics in production
    if (process.env.NODE_ENV === 'production') {
      this.sendToAnalytics(report);
    }

    // Alert if poor performance
    if (rating === 'poor') {
      console.warn(`⚠️ Poor ${metric.name}: ${metric.value.toFixed(2)}ms`);
    }
  }

  private getRating(metric: Metric): 'good' | 'needs-improvement' | 'poor' {
    const thresholds = {
      LCP: { good: 2500, poor: 4000 },
      FID: { good: 100, poor: 300 },
      CLS: { good: 0.1, poor: 0.25 },
      FCP: { good: 1800, poor: 3000 },
      TTFB: { good: 800, poor: 1800 },
    };

    const threshold = thresholds[metric.name as keyof typeof thresholds];
    if (!threshold) return 'good';

    if (metric.value <= threshold.good) return 'good';
    if (metric.value <= threshold.poor) return 'needs-improvement';
    return 'poor';
  }

  private async sendToAnalytics(report: WebVitalsReport) {
    try {
      // Send to Google Analytics 4
      if (typeof window !== 'undefined' && (window as any).gtag) {
        (window as any).gtag('event', report.name, {
          event_category: 'Web Vitals',
          value: Math.round(report.value),
          event_label: report.id,
          non_interaction: true,
        });
      }

      // Send to custom analytics endpoint
      await fetch('/api/analytics/web-vitals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(report),
        keepalive: true,
      });
    } catch (error) {
      console.error('Failed to send web vitals:', error);
    }
  }

  getMetrics(): WebVitalsReport[] {
    return Array.from(this.metrics.values());
  }

  getScore(): number {
    const metrics = this.getMetrics();
    if (metrics.length === 0) return 0;

    const scores = metrics.map((m): number => {
      if (m.rating === 'good') return 100;
      if (m.rating === 'needs-improvement') return 50;
      return 0;
    });

    return Math.round(scores.reduce((a, b) => a + b, 0) / scores.length);
  }

  printReport() {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📊 WEB VITALS PERFORMANCE REPORT');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`Overall Score: ${this.getScore()}/100`);
    console.log('');

    this.getMetrics().forEach((metric) => {
      const icon = metric.rating === 'good' ? '✅' : metric.rating === 'needs-improvement' ? '⚠️' : '❌';
      console.log(`${icon} ${metric.name}: ${metric.value.toFixed(2)}ms (${metric.rating})`);
    });

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}

export const webVitalsTracker = new WebVitalsTracker();
export default webVitalsTracker;
