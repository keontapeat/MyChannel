/**
 * Video Ad Formats (YouTube Standard)
 * 
 * Defines all YouTube ad formats with specifications and billing rules.
 */

/**
 * Ad Format Definitions
 */
export const AD_FORMATS = {
  /**
   * Skippable In-Stream (TrueView)
   * - Most common YouTube format
   * - 5-second forced view, then skip button
   * - Advertiser pays only if viewed 30s+ or clicked
   */
  SKIPPABLE_INSTREAM: {
    id: 'skippable_instream',
    name: 'Skippable In-Stream',
    type: 'video',
    linear: true,
    skippable: true,
    skipAfter: 5, // seconds
    minDuration: 12,
    maxDuration: 360, // 6 minutes
    recommendedDuration: [15, 20, 30, 60],
    placements: ['pre_roll', 'mid_roll', 'post_roll'],
    billingEvent: 'view_30s_or_complete',
    billingThreshold: 30, // seconds
    pricingModels: ['cpv', 'cpm'],
    targeting: ['demographic', 'interest', 'contextual', 'remarketing'],
    features: {
      companionAds: true,
      overlay: false,
      interactive: true,
      expandable: false
    },
    specs: {
      videoCodec: ['H.264', 'VP9'],
      audioCodec: ['AAC', 'Opus'],
      container: ['MP4', 'WebM'],
      aspectRatio: ['16:9', '4:3', '1:1', '9:16'],
      resolution: {
        min: { width: 640, height: 360 },
        recommended: { width: 1920, height: 1080 },
        max: { width: 3840, height: 2160 }
      },
      bitrate: {
        min: 500, // kbps
        recommended: 2000,
        max: 10000
      },
      fileSize: {
        max: 1024 * 1024 * 1024 // 1GB
      }
    }
  },

  /**
   * Non-Skippable In-Stream
   * - 15-20 seconds, must watch
   * - Higher CPM, guaranteed views
   * - Premium inventory
   */
  NON_SKIPPABLE_INSTREAM: {
    id: 'non_skippable_instream',
    name: 'Non-Skippable In-Stream',
    type: 'video',
    linear: true,
    skippable: false,
    skipAfter: null,
    minDuration: 15,
    maxDuration: 20,
    recommendedDuration: [15, 20],
    placements: ['pre_roll', 'mid_roll'],
    billingEvent: 'impression',
    billingThreshold: 0,
    pricingModels: ['cpm'],
    targeting: ['demographic', 'interest', 'contextual'],
    features: {
      companionAds: true,
      overlay: false,
      interactive: false,
      expandable: false
    },
    specs: {
      videoCodec: ['H.264', 'VP9'],
      audioCodec: ['AAC', 'Opus'],
      container: ['MP4', 'WebM'],
      aspectRatio: ['16:9'],
      resolution: {
        min: { width: 640, height: 360 },
        recommended: { width: 1920, height: 1080 },
        max: { width: 1920, height: 1080 }
      },
      bitrate: {
        min: 1000,
        recommended: 2000,
        max: 5000
      },
      fileSize: {
        max: 100 * 1024 * 1024 // 100MB
      }
    }
  },

  /**
   * Bumper Ads
   * - 6 seconds, non-skippable
   * - Brand awareness campaigns
   * - High reach, low cost
   */
  BUMPER: {
    id: 'bumper',
    name: 'Bumper Ad',
    type: 'video',
    linear: true,
    skippable: false,
    skipAfter: null,
    minDuration: 6,
    maxDuration: 6,
    recommendedDuration: [6],
    placements: ['pre_roll', 'post_roll'],
    billingEvent: 'impression',
    billingThreshold: 0,
    pricingModels: ['cpm'],
    targeting: ['demographic', 'interest', 'contextual'],
    features: {
      companionAds: false,
      overlay: false,
      interactive: false,
      expandable: false
    },
    specs: {
      videoCodec: ['H.264', 'VP9'],
      audioCodec: ['AAC', 'Opus'],
      container: ['MP4', 'WebM'],
      aspectRatio: ['16:9'],
      resolution: {
        min: { width: 640, height: 360 },
        recommended: { width: 1920, height: 1080 },
        max: { width: 1920, height: 1080 }
      },
      bitrate: {
        min: 1000,
        recommended: 2000,
        max: 3000
      },
      fileSize: {
        max: 10 * 1024 * 1024 // 10MB
      }
    }
  },

  /**
   * Overlay Ads
   * - Semi-transparent banner on video
   * - Desktop only
   * - Non-intrusive
   */
  OVERLAY: {
    id: 'overlay',
    name: 'Overlay Ad',
    type: 'image',
    linear: false,
    skippable: true,
    skipAfter: 0,
    minDuration: null,
    maxDuration: null,
    recommendedDuration: [null], // Persistent
    placements: ['overlay'],
    billingEvent: 'click',
    billingThreshold: 0,
    pricingModels: ['cpc', 'cpm'],
    targeting: ['demographic', 'interest', 'contextual'],
    features: {
      companionAds: false,
      overlay: true,
      interactive: true,
      expandable: false
    },
    specs: {
      imageFormat: ['PNG', 'JPEG', 'GIF'],
      sizes: [
        { width: 468, height: 60, name: 'Banner' },
        { width: 728, height: 90, name: 'Leaderboard' },
        { width: 300, height: 250, name: 'Medium Rectangle' }
      ],
      fileSize: {
        max: 150 * 1024 // 150KB
      },
      animation: {
        maxDuration: 30, // seconds
        maxLoops: 3
      }
    }
  },

  /**
   * Mid-Roll Ads
   * - Inserted during video (8+ min videos)
   * - Natural break points
   * - Higher engagement
   */
  MID_ROLL: {
    id: 'mid_roll',
    name: 'Mid-Roll Ad',
    type: 'video',
    linear: true,
    skippable: true,
    skipAfter: 5,
    minDuration: 12,
    maxDuration: 360,
    recommendedDuration: [15, 20, 30],
    placements: ['mid_roll'],
    billingEvent: 'view_30s_or_complete',
    billingThreshold: 30,
    pricingModels: ['cpv', 'cpm'],
    targeting: ['demographic', 'interest', 'contextual', 'remarketing'],
    requirements: {
      minVideoLength: 480, // 8 minutes
      maxAdsPerVideo: 4,
      minTimeBetweenAds: 420 // 7 minutes
    },
    features: {
      companionAds: true,
      overlay: false,
      interactive: true,
      expandable: false
    },
    specs: {
      videoCodec: ['H.264', 'VP9'],
      audioCodec: ['AAC', 'Opus'],
      container: ['MP4', 'WebM'],
      aspectRatio: ['16:9'],
      resolution: {
        min: { width: 640, height: 360 },
        recommended: { width: 1920, height: 1080 },
        max: { width: 3840, height: 2160 }
      },
      bitrate: {
        min: 500,
        recommended: 2000,
        max: 10000
      },
      fileSize: {
        max: 1024 * 1024 * 1024 // 1GB
      }
    }
  },

  /**
   * Masthead Ads
   * - Homepage takeover
   * - Premium placement
   * - Reserved buying only
   */
  MASTHEAD: {
    id: 'masthead',
    name: 'Masthead Ad',
    type: 'video',
    linear: false,
    skippable: true,
    skipAfter: 0,
    minDuration: 15,
    maxDuration: 30,
    recommendedDuration: [15, 20, 30],
    placements: ['homepage'],
    billingEvent: 'impression',
    billingThreshold: 0,
    pricingModels: ['cpd'], // Cost per day
    targeting: ['demographic', 'geo'],
    features: {
      companionAds: true,
      overlay: false,
      interactive: true,
      expandable: true,
      autoplay: true,
      muted: true
    },
    specs: {
      videoCodec: ['H.264', 'VP9'],
      audioCodec: ['AAC', 'Opus'],
      container: ['MP4', 'WebM'],
      aspectRatio: ['16:9'],
      resolution: {
        min: { width: 1920, height: 1080 },
        recommended: { width: 1920, height: 1080 },
        max: { width: 1920, height: 1080 }
      },
      bitrate: {
        min: 2000,
        recommended: 3000,
        max: 5000
      },
      fileSize: {
        max: 200 * 1024 * 1024 // 200MB
      }
    }
  }
}

/**
 * Get ad format by ID.
 */
export function getAdFormat(formatId) {
  return AD_FORMATS[formatId.toUpperCase()] || null
}

/**
 * Get all ad formats.
 */
export function getAllAdFormats() {
  return Object.values(AD_FORMATS)
}

/**
 * Get ad formats by placement.
 */
export function getAdFormatsByPlacement(placement) {
  return Object.values(AD_FORMATS).filter(format => 
    format.placements.includes(placement)
  )
}

/**
 * Get ad formats by type.
 */
export function getAdFormatsByType(type) {
  return Object.values(AD_FORMATS).filter(format => 
    format.type === type
  )
}

/**
 * Validate creative against format specs.
 */
export function validateCreative(creative, formatId) {
  const format = getAdFormat(formatId)
  if (!format) {
    return { isValid: false, errors: ['Invalid format ID'] }
  }
  
  const errors = []
  
  // Duration validation
  if (format.minDuration && creative.duration < format.minDuration) {
    errors.push(`Duration too short (min: ${format.minDuration}s)`)
  }
  if (format.maxDuration && creative.duration > format.maxDuration) {
    errors.push(`Duration too long (max: ${format.maxDuration}s)`)
  }
  
  // Resolution validation
  if (format.specs.resolution) {
    const { min, max } = format.specs.resolution
    if (creative.width < min.width || creative.height < min.height) {
      errors.push(`Resolution too low (min: ${min.width}x${min.height})`)
    }
    if (max && (creative.width > max.width || creative.height > max.height)) {
      errors.push(`Resolution too high (max: ${max.width}x${max.height})`)
    }
  }
  
  // File size validation
  if (format.specs.fileSize && creative.fileSize > format.specs.fileSize.max) {
    errors.push(`File size too large (max: ${format.specs.fileSize.max / 1024 / 1024}MB)`)
  }
  
  // Bitrate validation
  if (format.specs.bitrate && creative.bitrate) {
    if (creative.bitrate < format.specs.bitrate.min) {
      errors.push(`Bitrate too low (min: ${format.specs.bitrate.min}kbps)`)
    }
    if (creative.bitrate > format.specs.bitrate.max) {
      errors.push(`Bitrate too high (max: ${format.specs.bitrate.max}kbps)`)
    }
  }
  
  // Codec validation
  if (format.specs.videoCodec && creative.videoCodec) {
    if (!format.specs.videoCodec.includes(creative.videoCodec)) {
      errors.push(`Invalid video codec (allowed: ${format.specs.videoCodec.join(', ')})`)
    }
  }
  
  return {
    isValid: errors.length === 0,
    errors,
    format
  }
}

/**
 * Calculate billing for ad view.
 */
export function calculateBilling(formatId, viewDuration, clicked, pricing) {
  const format = getAdFormat(formatId)
  if (!format) return { billable: false, amount: 0 }
  
  let billable = false
  let amount = 0
  
  switch (format.billingEvent) {
    case 'impression':
      billable = true
      amount = pricing.cpm / 1000
      break
      
    case 'view_30s_or_complete':
      billable = viewDuration >= format.billingThreshold || viewDuration >= format.maxDuration
      amount = billable ? pricing.cpv : 0
      break
      
    case 'click':
      billable = clicked
      amount = billable ? pricing.cpc : 0
      break
      
    case 'cpd':
      billable = true
      amount = pricing.cpd
      break
  }
  
  return {
    billable,
    amount,
    billingEvent: format.billingEvent,
    viewDuration,
    clicked
  }
}

/**
 * Get recommended ad format for context.
 */
export function recommendAdFormat(context) {
  const {
    placement = 'pre_roll',
    videoLength = 0,
    device = 'desktop',
    objective = 'awareness'
  } = context
  
  // Mid-roll only for long videos
  if (placement === 'mid_roll' && videoLength < 480) {
    return null
  }
  
  // Overlay only for desktop
  if (device === 'mobile' && placement === 'overlay') {
    return null
  }
  
  // Recommend based on objective
  if (objective === 'awareness') {
    return AD_FORMATS.BUMPER
  }
  
  if (objective === 'consideration') {
    return AD_FORMATS.SKIPPABLE_INSTREAM
  }
  
  if (objective === 'conversion') {
    return AD_FORMATS.NON_SKIPPABLE_INSTREAM
  }
  
  // Default
  return AD_FORMATS.SKIPPABLE_INSTREAM
}
