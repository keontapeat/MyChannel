/**
 * 🎯 MyChannel Ads - TypeScript Types
 * YouTube-Level Ad Platform Types
 */

// ============================================================================
// CAMPAIGN TYPES
// ============================================================================

export type CampaignStatus = 'draft' | 'active' | 'paused' | 'completed' | 'archived';
export type CampaignObjective = 
  | 'awareness'      // Brand awareness (bumper ads, masthead)
  | 'consideration'  // Product consideration (skippable in-stream)
  | 'conversion'     // Drive conversions (non-skippable, action-focused)
  | 'traffic'        // Website traffic
  | 'engagement';    // Video engagement

export interface Campaign {
  id: string;
  advertiserId: string;
  name: string;
  objective: CampaignObjective;
  status: CampaignStatus;
  budget: {
    total: number;           // Total budget in cents
    daily?: number;          // Daily budget cap in cents
    spent: number;           // Amount spent so far in cents
    remaining: number;       // Remaining budget in cents
  };
  schedule: {
    startDate: string;       // ISO 8601
    endDate?: string;        // ISO 8601 (optional for ongoing)
    timezone: string;        // IANA timezone
  };
  targeting: TargetingRules;
  creatives: Creative[];
  metrics: CampaignMetrics;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// TARGETING TYPES
// ============================================================================

export interface TargetingRules {
  geo?: GeoTargeting;
  demographic?: DemographicTargeting;
  device?: DeviceTargeting;
  contextual?: ContextualTargeting;
  behavioral?: BehavioralTargeting;
  remarketing?: RemarketingTargeting;
  custom?: CustomTargeting;
}

export interface GeoTargeting {
  countries?: string[];      // ISO 3166-1 alpha-2 codes
  regions?: string[];        // State/province codes
  cities?: string[];         // City names
  postalCodes?: string[];    // Postal/ZIP codes
  radius?: {                 // Radius targeting
    lat: number;
    lng: number;
    radiusKm: number;
  };
  exclude?: {                // Exclusions
    countries?: string[];
    regions?: string[];
    cities?: string[];
  };
}

export interface DemographicTargeting {
  age?: {
    min: number;             // 18-65+
    max: number;
  };
  gender?: ('male' | 'female' | 'other' | 'unknown')[];
  parentalStatus?: ('parent' | 'not_parent' | 'unknown')[];
  householdIncome?: ('top_10' | 'top_20' | 'top_30' | 'top_40' | 'top_50' | 'lower_50')[];
}

export interface DeviceTargeting {
  types?: ('desktop' | 'mobile' | 'tablet' | 'tv' | 'game_console')[];
  os?: ('ios' | 'android' | 'windows' | 'macos' | 'linux' | 'other')[];
  browsers?: ('chrome' | 'safari' | 'firefox' | 'edge' | 'other')[];
  connectionType?: ('wifi' | 'cellular' | 'ethernet')[];
}

export interface ContextualTargeting {
  topics?: string[];         // IAB content categories
  keywords?: string[];       // Video title/description keywords
  placements?: {             // Specific channels/videos
    channels?: string[];
    videos?: string[];
  };
  contentRating?: ('g' | 'pg' | 'pg13' | 'r' | 'x')[];
  excludeCategories?: string[]; // Brand safety exclusions
}

export interface BehavioralTargeting {
  interests?: string[];      // Affinity audiences
  inMarket?: string[];       // In-market audiences
  lifeEvents?: string[];     // Life event audiences
  videoHistory?: {           // Based on viewing history
    categories?: string[];
    channels?: string[];
  };
}

export interface RemarketingTargeting {
  websiteVisitors?: {
    url: string;
    lookbackDays: number;
  };
  appUsers?: {
    appId: string;
    lookbackDays: number;
  };
  videoEngagement?: {
    videoIds?: string[];
    channelIds?: string[];
    engagementType: 'view' | 'like' | 'comment' | 'subscribe';
    lookbackDays: number;
  };
}

export interface CustomTargeting {
  customerMatch?: {          // Upload email lists
    hashedEmails: string[];  // SHA-256 hashed
  };
  similarAudiences?: {       // Lookalike audiences
    seedAudienceId: string;
    expansionLevel: 1 | 2 | 3 | 4 | 5; // 1=narrow, 5=broad
  };
}

// ============================================================================
// CREATIVE TYPES
// ============================================================================

export type AdFormat = 
  | 'skippable_instream'     // TrueView
  | 'non_skippable_instream' // 15-20s forced view
  | 'bumper'                 // 6s non-skippable
  | 'overlay'                // Banner overlay
  | 'mid_roll'               // Mid-video ad
  | 'masthead';              // Homepage takeover

export type CreativeStatus = 'pending' | 'approved' | 'rejected' | 'active' | 'paused';

export interface Creative {
  id: string;
  campaignId: string;
  name: string;
  format: AdFormat;
  status: CreativeStatus;
  video?: {
    url: string;             // Video file URL
    duration: number;        // Duration in seconds
    thumbnail: string;       // Thumbnail URL
    width: number;
    height: number;
    fileSize: number;        // Bytes
  };
  companion?: {              // Companion banner (for overlay/display)
    imageUrl: string;
    width: number;
    height: number;
    clickUrl: string;
  };
  callToAction?: {
    text: string;            // "Learn More", "Shop Now", etc.
    url: string;             // Landing page URL
  };
  tracking: {
    impressionUrl?: string;
    clickUrl?: string;
    quartileUrls?: {
      firstQuartile?: string;
      midpoint?: string;
      thirdQuartile?: string;
      complete?: string;
    };
  };
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// BIDDING TYPES
// ============================================================================

export type BiddingStrategy = 
  | 'manual_cpm'             // Manual CPM bidding
  | 'manual_cpv'             // Manual CPV bidding
  | 'target_cpa'             // Target cost per acquisition
  | 'target_roas'            // Target return on ad spend
  | 'maximize_conversions'   // Maximize conversions within budget
  | 'maximize_conversion_value' // Maximize revenue within budget
  | 'target_impression_share'; // Maintain visibility %

export interface BiddingConfig {
  strategy: BiddingStrategy;
  manualBid?: number;        // Manual bid in cents (CPM/CPV)
  targetCpa?: number;        // Target CPA in cents
  targetRoas?: number;       // Target ROAS (e.g., 4.0 = 400%)
  targetImpressionShare?: {
    percentage: number;      // 0-100
    location: 'anywhere' | 'top' | 'absolute_top';
  };
}

// ============================================================================
// METRICS TYPES
// ============================================================================

export interface CampaignMetrics {
  impressions: number;
  views: number;             // 30s+ views or complete
  clicks: number;
  conversions: number;
  spend: number;             // Total spend in cents
  
  // Calculated metrics
  ctr: number;               // Click-through rate (%)
  vtr: number;               // View-through rate (%)
  cpm: number;               // Cost per 1000 impressions (cents)
  cpv: number;               // Cost per view (cents)
  cpc: number;               // Cost per click (cents)
  cpa: number;               // Cost per acquisition (cents)
  roas: number;              // Return on ad spend
  
  // Video metrics
  quartiles: {
    firstQuartile: number;   // 25% completion
    midpoint: number;        // 50% completion
    thirdQuartile: number;   // 75% completion
    complete: number;        // 100% completion
  };
  
  // Engagement
  likes: number;
  shares: number;
  comments: number;
  
  // Time series (for charts)
  timeSeries?: MetricTimeSeries[];
}

export interface MetricTimeSeries {
  date: string;              // ISO 8601 date
  impressions: number;
  views: number;
  clicks: number;
  conversions: number;
  spend: number;
}

// ============================================================================
// PUBLISHER TYPES
// ============================================================================

export type MonetizationStatus = 'eligible' | 'pending' | 'ineligible' | 'suspended';

export interface PublisherProfile {
  userId: string;
  channelId: string;
  status: MonetizationStatus;
  eligibility: {
    subscribers: number;      // Current count
    watchHours: number;       // Last 12 months
    meetsRequirements: boolean;
    requirements: {
      minSubscribers: number; // 1000
      minWatchHours: number;  // 4000
    };
  };
  adSettings: PublisherAdSettings;
  revenue: PublisherRevenue;
  paymentInfo: PaymentInfo;
}

export interface PublisherAdSettings {
  enabled: boolean;
  formats: {
    skippableInstream: boolean;
    nonSkippableInstream: boolean;
    bumper: boolean;
    overlay: boolean;
    midRoll: boolean;
  };
  midRollSettings: {
    enabled: boolean;
    frequency: 'auto' | 'manual';
    minVideoLength: number;  // Minimum video length for mid-rolls (seconds)
    breakInterval: number;   // Seconds between breaks (for auto)
  };
  blockedCategories: string[]; // IAB categories to block
  blockedAdvertisers: string[]; // Specific advertiser IDs to block
  suitability: 'limited' | 'standard' | 'expanded'; // Content suitability
}

export interface PublisherRevenue {
  lifetime: number;          // Total earnings in cents
  thisMonth: number;         // Current month earnings in cents
  lastMonth: number;         // Last month earnings in cents
  pending: number;           // Pending payout in cents
  
  // Metrics
  rpm: number;               // Revenue per 1000 views (cents)
  cpm: number;               // Cost per 1000 impressions (cents)
  
  // Breakdown
  byFormat: {
    [format: string]: number; // Revenue by ad format
  };
  byVideo: {
    videoId: string;
    title: string;
    revenue: number;
    views: number;
    rpm: number;
  }[];
}

export interface PaymentInfo {
  stripeAccountId?: string;  // Stripe Connect account
  paymentMethod: 'stripe' | 'bank_transfer' | 'paypal';
  minimumPayout: number;     // Minimum payout threshold (cents)
  schedule: 'monthly' | 'weekly'; // Payment schedule
  lastPayout?: {
    amount: number;
    date: string;
    status: 'pending' | 'completed' | 'failed';
  };
  nextPayout?: {
    estimatedAmount: number;
    estimatedDate: string;
  };
}

// ============================================================================
// VIDEO AD SETTINGS (per video)
// ============================================================================

export interface VideoAdSettings {
  videoId: string;
  monetizationEnabled: boolean;
  adFormats: {
    skippableInstream: boolean;
    nonSkippableInstream: boolean;
    bumper: boolean;
    overlay: boolean;
  };
  midRollBreaks: MidRollBreak[];
  blockedCategories: string[];
  blockedAdvertisers: string[];
  suitability: 'limited' | 'standard' | 'expanded';
}

export interface MidRollBreak {
  timestamp: number;         // Seconds into video
  type: 'auto' | 'manual';
}

// ============================================================================
// ANALYTICS TYPES
// ============================================================================

export interface AnalyticsReport {
  dateRange: {
    start: string;           // ISO 8601
    end: string;             // ISO 8601
  };
  dimensions: string[];      // ['date', 'device', 'geo', etc.]
  metrics: CampaignMetrics;
  breakdown: AnalyticsBreakdown[];
}

export interface AnalyticsBreakdown {
  dimension: string;         // 'device', 'geo', 'age', etc.
  value: string;             // 'mobile', 'US', '18-24', etc.
  metrics: CampaignMetrics;
}

// ============================================================================
// AUDIENCE TYPES
// ============================================================================

export interface SavedAudience {
  id: string;
  advertiserId: string;
  name: string;
  description?: string;
  targeting: TargetingRules;
  estimatedReach: number;    // Estimated audience size
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// NOTIFICATION TYPES
// ============================================================================

export type NotificationType = 
  | 'campaign_approved'
  | 'campaign_rejected'
  | 'budget_depleted'
  | 'low_performance'
  | 'payment_received'
  | 'payment_failed'
  | 'eligibility_approved'
  | 'eligibility_rejected';

export interface AdNotification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  message: string;
  data?: Record<string, any>;
  read: boolean;
  createdAt: string;
}
