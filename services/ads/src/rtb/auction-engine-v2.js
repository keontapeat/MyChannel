/**
 * MyChannel Ads — Production RTB Engine (YouTube-Level)
 * 
 * Multi-stage auction pipeline:
 * 1. Pre-filtering (targeting, budget, frequency caps)
 * 2. CTR/VTR prediction (ML-powered)
 * 3. eCPM calculation
 * 4. Second-price auction
 * 5. Creative selection
 * 6. Post-auction validation
 * 
 * Performance targets:
 * - Latency: <50ms p99
 * - Throughput: 100K+ QPS per instance
 * - Fill rate: >95%
 */

import { predictCtr as legacyPredictCtr, ecpmCents as legacyEcpmCents } from '../lib/auction.js'

// ============================================================================
// CONSTANTS & CONFIGURATION
// ============================================================================

const CONFIG = {
  // CTR Prediction
  GLOBAL_PRIOR_CTR: 0.004,      // 0.4% baseline
  PRIOR_WEIGHT: 200,             // Bayesian prior weight
  MIN_CTR: 0.0001,               // 0.01% floor
  MAX_CTR: 0.25,                 // 25% ceiling
  
  // VTR Prediction (Video Through Rate)
  GLOBAL_PRIOR_VTR: 0.65,        // 65% baseline completion
  VTR_WEIGHT: 100,
  
  // Auction
  MIN_BID_CENTS: 10,             // $0.10 minimum bid
  MAX_BID_CENTS: 1000000,        // $10,000 maximum bid
  SECOND_PRICE_INCREMENT: 1,     // +1 cent above runner-up
  
  // Performance
  MAX_CANDIDATES: 1000,          // Limit candidates per auction
  CACHE_TTL_MS: 60000,           // 1 minute cache
  
  // Quality
  MIN_QUALITY_SCORE: 0.1,        // Minimum ad quality (0-1)
  VIEWABILITY_THRESHOLD: 0.5,    // 50% viewability minimum
}

// ============================================================================
// STAGE 1: PRE-FILTERING
// ============================================================================

/**
 * Pre-filter candidates based on hard constraints.
 * This is the fastest stage - eliminate ineligible candidates early.
 */
export class PreFilter {
  constructor(context) {
    this.context = context
    this.now = Date.now()
  }
  
  /**
   * Filter candidates by targeting, budget, and frequency caps.
   * @param {Array} candidates - Line items with targeting rules
   * @returns {Array} Eligible candidates
   */
  filter(candidates) {
    const eligible = []
    const rejected = []
    
    for (const candidate of candidates.slice(0, CONFIG.MAX_CANDIDATES)) {
      const reason = this.checkEligibility(candidate)
      if (reason === null) {
        eligible.push(candidate)
      } else {
        rejected.push({ candidate, reason })
      }
    }
    
    return {
      eligible,
      rejected,
      stats: {
        total: candidates.length,
        eligible: eligible.length,
        rejected: rejected.length,
        rejectionReasons: this.groupRejections(rejected)
      }
    }
  }
  
  /**
   * Check if candidate is eligible.
   * @returns {string|null} Rejection reason or null if eligible
   */
  checkEligibility(candidate) {
    // Status check
    if (candidate.status !== 'active') {
      return 'inactive'
    }
    
    // Campaign status
    if (candidate.campaign_status !== 'active') {
      return 'campaign_inactive'
    }
    
    // Budget check
    if (candidate.budget_cents !== null && candidate.spent_cents >= candidate.budget_cents) {
      return 'budget_exhausted'
    }
    
    // Daily budget check
    if (candidate.daily_cap_cents && candidate.daily_spent_cents >= candidate.daily_cap_cents) {
      return 'daily_budget_exhausted'
    }
    
    // Flight dates
    if (candidate.start_at && new Date(candidate.start_at) > this.now) {
      return 'not_started'
    }
    if (candidate.end_at && new Date(candidate.end_at) < this.now) {
      return 'ended'
    }
    
    // Frequency cap
    if (this.exceedsFrequencyCap(candidate)) {
      return 'frequency_capped'
    }
    
    // Geo targeting
    if (!this.matchesGeoTargeting(candidate)) {
      return 'geo_mismatch'
    }
    
    // Device targeting
    if (!this.matchesDeviceTargeting(candidate)) {
      return 'device_mismatch'
    }
    
    // Demographic targeting
    if (!this.matchesDemographicTargeting(candidate)) {
      return 'demographic_mismatch'
    }
    
    // Contextual targeting
    if (!this.matchesContextualTargeting(candidate)) {
      return 'contextual_mismatch'
    }
    
    // Brand safety
    if (!this.passesBrandSafety(candidate)) {
      return 'brand_safety'
    }
    
    return null // Eligible
  }
  
  exceedsFrequencyCap(candidate) {
    if (!candidate.frequency_cap || !this.context.userId) return false
    
    const key = `freq:${candidate.id}:${this.context.userId}`
    const count = this.context.frequencyCache?.get(key) || 0
    
    return count >= candidate.frequency_cap
  }
  
  matchesGeoTargeting(candidate) {
    if (!candidate.geo || candidate.geo.length === 0) return true
    if (!this.context.country) return false
    
    return candidate.geo.includes(this.context.country)
  }
  
  matchesDeviceTargeting(candidate) {
    if (!candidate.devices || candidate.devices.length === 0) return true
    if (!this.context.device) return false
    
    return candidate.devices.includes(this.context.device)
  }
  
  matchesDemographicTargeting(candidate) {
    const targeting = candidate.targeting_json || {}
    
    // Age targeting
    if (targeting.age && this.context.age) {
      const [min, max] = targeting.age
      if (this.context.age < min || this.context.age > max) return false
    }
    
    // Gender targeting
    if (targeting.gender && this.context.gender) {
      if (!targeting.gender.includes(this.context.gender)) return false
    }
    
    return true
  }
  
  matchesContextualTargeting(candidate) {
    const targeting = candidate.targeting_json || {}
    
    // Topic targeting
    if (targeting.topics && this.context.videoTopics) {
      const hasMatch = targeting.topics.some(t => this.context.videoTopics.includes(t))
      if (!hasMatch) return false
    }
    
    // Keyword targeting
    if (targeting.keywords && this.context.videoKeywords) {
      const hasMatch = targeting.keywords.some(k => 
        this.context.videoKeywords.some(vk => vk.toLowerCase().includes(k.toLowerCase()))
      )
      if (!hasMatch) return false
    }
    
    // Channel/video placement targeting
    if (targeting.placements) {
      const { channelId, videoId } = this.context
      const hasMatch = targeting.placements.some(p => 
        p.channelId === channelId || p.videoId === videoId
      )
      if (!hasMatch) return false
    }
    
    return true
  }
  
  passesBrandSafety(candidate) {
    const { contentRating, sensitiveCategories = [] } = this.context
    const { blocked_categories = [], allow_sensitive = false } = candidate
    
    // Check content rating
    if (contentRating && candidate.max_content_rating) {
      const ratings = ['G', 'PG', 'PG-13', 'R', 'X']
      const contentLevel = ratings.indexOf(contentRating)
      const maxLevel = ratings.indexOf(candidate.max_content_rating)
      if (contentLevel > maxLevel) return false
    }
    
    // Check sensitive categories
    if (!allow_sensitive && sensitiveCategories.length > 0) {
      return false
    }
    
    // Check blocked categories
    if (blocked_categories.length > 0) {
      const hasBlocked = sensitiveCategories.some(c => blocked_categories.includes(c))
      if (hasBlocked) return false
    }
    
    return true
  }
  
  groupRejections(rejected) {
    const groups = {}
    for (const { reason } of rejected) {
      groups[reason] = (groups[reason] || 0) + 1
    }
    return groups
  }
}

// ============================================================================
// STAGE 2: CTR/VTR PREDICTION
// ============================================================================

/**
 * Predict click-through rate and video-through rate.
 * Uses ML models when available, falls back to Bayesian smoothing.
 */
export class PredictionEngine {
  constructor(mlService = null) {
    this.mlService = mlService
  }
  
  /**
   * Predict CTR for a candidate.
   */
  async predictCtr(candidate, context) {
    // Try ML model first
    if (this.mlService) {
      try {
        const features = this.extractFeatures(candidate, context)
        const prediction = await this.mlService.predictCtr(features)
        if (prediction !== null) {
          return this.clampCtr(prediction)
        }
      } catch (err) {
        console.warn('ML CTR prediction failed, falling back to Bayesian:', err.message)
      }
    }
    
    // Fall back to Bayesian smoothing
    return this.bayesianCtr(candidate)
  }
  
  /**
   * Predict VTR (video completion rate) for video ads.
   */
  async predictVtr(candidate, context) {
    if (this.mlService) {
      try {
        const features = this.extractFeatures(candidate, context)
        const prediction = await this.mlService.predictVtr(features)
        if (prediction !== null) {
          return Math.max(0.1, Math.min(1.0, prediction))
        }
      } catch (err) {
        console.warn('ML VTR prediction failed, falling back to Bayesian:', err.message)
      }
    }
    
    return this.bayesianVtr(candidate)
  }
  
  /**
   * Bayesian CTR with historical data.
   */
  bayesianCtr(candidate) {
    const clicks = candidate.hist_clicks || 0
    const impressions = candidate.hist_impressions || 0
    const prior = CONFIG.GLOBAL_PRIOR_CTR
    const weight = CONFIG.PRIOR_WEIGHT
    
    const ctr = (clicks + prior * weight) / (impressions + weight)
    return this.clampCtr(ctr)
  }
  
  /**
   * Bayesian VTR with historical data.
   */
  bayesianVtr(candidate) {
    const completions = candidate.hist_completions || 0
    const starts = candidate.hist_starts || 0
    const prior = CONFIG.GLOBAL_PRIOR_VTR
    const weight = CONFIG.VTR_WEIGHT
    
    const vtr = (completions + prior * weight) / (starts + weight)
    return Math.max(0.1, Math.min(1.0, vtr))
  }
  
  clampCtr(ctr) {
    return Math.max(CONFIG.MIN_CTR, Math.min(CONFIG.MAX_CTR, ctr))
  }
  
  /**
   * Extract features for ML model.
   */
  extractFeatures(candidate, context) {
    return {
      // Candidate features
      lineItemId: candidate.id,
      campaignId: candidate.campaign_id,
      advertiserId: candidate.advertiser_id,
      pricingModel: candidate.pricing_model,
      bidCents: candidate.bid_cpm_cents || candidate.bid_cpc_cents,
      format: candidate.format,
      duration: candidate.duration_sec,
      
      // Historical performance
      histClicks: candidate.hist_clicks || 0,
      histImpressions: candidate.hist_impressions || 0,
      histCompletions: candidate.hist_completions || 0,
      histStarts: candidate.hist_starts || 0,
      
      // Context features
      device: context.device,
      country: context.country,
      hour: new Date().getHours(),
      dayOfWeek: new Date().getDay(),
      videoCategory: context.videoCategory,
      channelSubscribers: context.channelSubscribers,
      
      // User features (if available)
      userAge: context.age,
      userGender: context.gender,
      userInterests: context.interests || [],
    }
  }
}

// ============================================================================
// STAGE 3: ECPM CALCULATION
// ============================================================================

/**
 * Calculate effective CPM for each candidate.
 */
export function calculateEcpm(candidate, predictedCtr, predictedVtr, context) {
  const { pricing_model } = candidate
  
  if (pricing_model === 'cpc') {
    // CPC: eCPM = CPC * CTR * 1000
    const bidCpc = Number(candidate.bid_cpc_cents) || 0
    return bidCpc * predictedCtr * 1000
  }
  
  if (pricing_model === 'cpv') {
    // CPV (Cost Per View): eCPM = CPV * VTR * 1000
    const bidCpv = Number(candidate.bid_cpv_cents) || 0
    return bidCpv * predictedVtr * 1000
  }
  
  if (pricing_model === 'cpm') {
    // CPM: eCPM = CPM
    return Number(candidate.bid_cpm_cents) || 0
  }
  
  // Default to CPM
  return Number(candidate.bid_cpm_cents) || 0
}

// ============================================================================
// STAGE 4: AUCTION
// ============================================================================

/**
 * Run second-price auction on eCPM.
 */
export class AuctionEngine {
  constructor(floorCents = 0) {
    this.floorCents = floorCents
  }
  
  /**
   * Run the auction.
   * @param {Array} scoredCandidates - Candidates with eCPM scores
   * @returns {object|null} Auction result
   */
  runAuction(scoredCandidates) {
    // Filter by floor
    const eligible = scoredCandidates.filter(c => c.ecpm >= this.floorCents)
    
    if (eligible.length === 0) {
      return null // No fill
    }
    
    // Sort by eCPM descending
    eligible.sort((a, b) => b.ecpm - a.ecpm)
    
    const winner = eligible[0]
    const runnerUp = eligible[1]
    
    // Second-price clearing
    const clearingEcpm = this.calculateClearingPrice(winner, runnerUp)
    
    // Convert clearing eCPM to actual price
    const clearingPrice = this.calculateClearingPriceCents(winner, clearingEcpm)
    
    return {
      winner: winner.candidate,
      predictedCtr: winner.predictedCtr,
      predictedVtr: winner.predictedVtr,
      winningEcpm: winner.ecpm,
      clearingEcpm,
      clearingPrice,
      runnerUpEcpm: runnerUp ? runnerUp.ecpm : null,
      diagnostics: {
        eligibleCount: eligible.length,
        floorEcpm: this.floorCents,
        topCandidates: eligible.slice(0, 5).map(c => ({
          lineItemId: c.candidate.id,
          pricingModel: c.candidate.pricing_model,
          ecpm: Math.round(c.ecpm),
          predictedCtr: Number(c.predictedCtr.toFixed(4)),
          predictedVtr: Number(c.predictedVtr.toFixed(4)),
        }))
      }
    }
  }
  
  /**
   * Calculate second-price clearing eCPM.
   */
  calculateClearingPrice(winner, runnerUp) {
    if (!runnerUp) {
      // No competition - pay floor
      return this.floorCents
    }
    
    // Pay just enough to beat runner-up
    const clearing = runnerUp.ecpm + CONFIG.SECOND_PRICE_INCREMENT
    
    // Clamp between floor and winner's bid
    return Math.max(
      this.floorCents,
      Math.min(winner.ecpm, clearing)
    )
  }
  
  /**
   * Convert clearing eCPM to actual price in advertiser's pricing model.
   */
  calculateClearingPriceCents(winner, clearingEcpm) {
    const { pricing_model } = winner.candidate
    
    if (pricing_model === 'cpc') {
      // CPC: price = clearingEcpm / (CTR * 1000)
      const pricePerClick = clearingEcpm / (winner.predictedCtr * 1000)
      const maxBid = Number(winner.candidate.bid_cpc_cents) || 0
      return Math.min(maxBid, Math.ceil(pricePerClick))
    }
    
    if (pricing_model === 'cpv') {
      // CPV: price = clearingEcpm / (VTR * 1000)
      const pricePerView = clearingEcpm / (winner.predictedVtr * 1000)
      const maxBid = Number(winner.candidate.bid_cpv_cents) || 0
      return Math.min(maxBid, Math.ceil(pricePerView))
    }
    
    // CPM: price = clearingEcpm
    return clearingEcpm
  }
}

// ============================================================================
// MAIN PIPELINE
// ============================================================================

/**
 * Run complete RTB pipeline.
 * @param {Array} candidates - Line items
 * @param {object} context - Request context
 * @param {object} options - Configuration options
 * @returns {Promise<object|null>} Auction result
 */
export async function runRtbAuction(candidates, context, options = {}) {
  const startTime = Date.now()
  
  try {
    // Stage 1: Pre-filtering
    const preFilter = new PreFilter(context)
    const { eligible, stats: filterStats } = preFilter.filter(candidates)
    
    if (eligible.length === 0) {
      return {
        result: null,
        reason: 'no_eligible_candidates',
        stats: { filterStats, latencyMs: Date.now() - startTime }
      }
    }
    
    // Stage 2: Prediction
    const predictor = new PredictionEngine(options.mlService)
    const scored = await Promise.all(
      eligible.map(async (candidate) => {
        const [predictedCtr, predictedVtr] = await Promise.all([
          predictor.predictCtr(candidate, context),
          predictor.predictVtr(candidate, context)
        ])
        
        const ecpm = calculateEcpm(candidate, predictedCtr, predictedVtr, context)
        
        return {
          candidate,
          predictedCtr,
          predictedVtr,
          ecpm
        }
      })
    )
    
    // Stage 3: Auction
    const auctionEngine = new AuctionEngine(options.floorCents || 0)
    const auctionResult = auctionEngine.runAuction(scored)
    
    if (!auctionResult) {
      return {
        result: null,
        reason: 'below_floor',
        stats: {
          filterStats,
          scoredCount: scored.length,
          latencyMs: Date.now() - startTime
        }
      }
    }
    
    // Success
    return {
      result: auctionResult,
      stats: {
        filterStats,
        scoredCount: scored.length,
        latencyMs: Date.now() - startTime
      }
    }
    
  } catch (error) {
    console.error('RTB auction error:', error)
    return {
      result: null,
      reason: 'error',
      error: error.message,
      stats: { latencyMs: Date.now() - startTime }
    }
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

// All classes and functions are already exported inline above
export { CONFIG }
