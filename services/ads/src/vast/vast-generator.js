/**
 * VAST 4.2 Generator (YouTube/Google Ad Manager Level)
 * 
 * Generates IAB VAST (Video Ad Serving Template) XML for video ads.
 * Supports all major ad formats and tracking events.
 * 
 * Spec: https://iabtechlab.com/standards/vast/
 */

/**
 * Generate VAST 4.2 XML for a video ad.
 * @param {object} ad - Ad creative with metadata
 * @param {object} tracking - Tracking URLs
 * @param {object} options - Generation options
 * @returns {string} VAST XML
 */
export function generateVAST(ad, tracking = {}, options = {}) {
  const {
    version = '4.2',
    adId = ad.id || generateAdId(),
    adSystem = 'MyChannel Ads',
    adTitle = ad.title || 'Video Advertisement',
    description = ad.description || '',
    advertiser = ad.advertiser || 'Advertiser',
    pricing = ad.pricing || {},
    extensions = []
  } = options

  const vastXml = `<?xml version="1.0" encoding="UTF-8"?>
<VAST version="${version}" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="http://www.iab.com/VAST">
  <Ad id="${adId}" sequence="1">
    <InLine>
      <AdSystem version="1.0">${escapeXml(adSystem)}</AdSystem>
      <AdTitle>${escapeXml(adTitle)}</AdTitle>
      ${description ? `<Description>${escapeXml(description)}</Description>` : ''}
      <Advertiser>${escapeXml(advertiser)}</Advertiser>
      ${generatePricing(pricing)}
      <Error><![CDATA[${tracking.error || ''}]]></Error>
      <Impression id="impression-1"><![CDATA[${tracking.impression || ''}]]></Impression>
      ${generateCreatives(ad, tracking)}
      ${generateExtensions(extensions)}
    </InLine>
  </Ad>
</VAST>`

  return vastXml.trim()
}

/**
 * Generate VAST wrapper (for mediation/header bidding).
 */
export function generateVASTWrapper(vastUrl, tracking = {}, options = {}) {
  const {
    version = '4.2',
    adId = generateAdId(),
    adSystem = 'MyChannel Ads',
    fallbackOnNoAd = true
  } = options

  return `<?xml version="1.0" encoding="UTF-8"?>
<VAST version="${version}" xmlns="http://www.iab.com/VAST">
  <Ad id="${adId}">
    <Wrapper ${fallbackOnNoAd ? 'fallbackOnNoAd="true"' : ''}>
      <AdSystem>${escapeXml(adSystem)}</AdSystem>
      <VASTAdTagURI><![CDATA[${vastUrl}]]></VASTAdTagURI>
      <Error><![CDATA[${tracking.error || ''}]]></Error>
      <Impression><![CDATA[${tracking.impression || ''}]]></Impression>
      <Creatives>
        <Creative>
          <Linear>
            <TrackingEvents>
              ${generateTrackingEvents(tracking)}
            </TrackingEvents>
          </Linear>
        </Creative>
      </Creatives>
    </Wrapper>
  </Ad>
</VAST>`
}

/**
 * Generate creatives section.
 */
function generateCreatives(ad, tracking) {
  const creatives = []
  
  // Linear creative (video ad)
  if (ad.type === 'video' || ad.format === 'video') {
    creatives.push(generateLinearCreative(ad, tracking))
  }
  
  // Companion ads (banner alongside video)
  if (ad.companions && ad.companions.length > 0) {
    creatives.push(generateCompanionAds(ad.companions, tracking))
  }
  
  // Non-linear ads (overlay)
  if (ad.overlay) {
    creatives.push(generateNonLinearCreative(ad.overlay, tracking))
  }
  
  return `<Creatives>${creatives.join('\n')}</Creatives>`
}

/**
 * Generate linear creative (main video ad).
 */
function generateLinearCreative(ad, tracking) {
  const {
    duration = ad.duration_sec || 30,
    skipOffset = ad.skipOffset || null,
    clickThrough = ad.click_url || '',
    clickTracking = tracking.click || '',
    videoUrl = ad.uri || ad.video_url,
    width = ad.width || 1920,
    height = ad.height || 1080,
    bitrate = ad.bitrate || 2000,
    mimeType = ad.mime_type || 'video/mp4',
    codec = ad.codec || 'h264'
  } = ad

  return `
    <Creative id="creative-${ad.id}" sequence="1">
      <Linear ${skipOffset ? `skipoffset="${formatSkipOffset(skipOffset)}"` : ''}>
        <Duration>${formatDuration(duration)}</Duration>
        <TrackingEvents>
          ${generateTrackingEvents(tracking)}
        </TrackingEvents>
        <VideoClicks>
          <ClickThrough><![CDATA[${clickThrough}]]></ClickThrough>
          ${clickTracking ? `<ClickTracking><![CDATA[${clickTracking}]]></ClickTracking>` : ''}
        </VideoClicks>
        <MediaFiles>
          <MediaFile delivery="progressive" type="${mimeType}" width="${width}" height="${height}" bitrate="${bitrate}" codec="${codec}">
            <![CDATA[${videoUrl}]]>
          </MediaFile>
        </MediaFiles>
        ${ad.icons ? generateIcons(ad.icons) : ''}
      </Linear>
    </Creative>`
}

/**
 * Generate companion ads (banners).
 */
function generateCompanionAds(companions, tracking) {
  const companionAds = companions.map(comp => `
    <Companion id="companion-${comp.id}" width="${comp.width}" height="${comp.height}">
      <StaticResource creativeType="${comp.mimeType || 'image/jpeg'}">
        <![CDATA[${comp.url}]]>
      </StaticResource>
      <CompanionClickThrough><![CDATA[${comp.clickUrl || ''}]]></CompanionClickThrough>
      ${comp.tracking ? `<TrackingEvents>${generateTrackingEvents(comp.tracking)}</TrackingEvents>` : ''}
    </Companion>
  `).join('\n')

  return `
    <Creative id="companion-creative" sequence="2">
      <CompanionAds>
        ${companionAds}
      </CompanionAds>
    </Creative>`
}

/**
 * Generate non-linear creative (overlay).
 */
function generateNonLinearCreative(overlay, tracking) {
  return `
    <Creative id="overlay-creative" sequence="3">
      <NonLinearAds>
        <NonLinear id="overlay-${overlay.id}" width="${overlay.width}" height="${overlay.height}" 
                   minSuggestedDuration="${formatDuration(overlay.duration || 0)}">
          <StaticResource creativeType="${overlay.mimeType || 'image/png'}">
            <![CDATA[${overlay.url}]]>
          </StaticResource>
          <NonLinearClickThrough><![CDATA[${overlay.clickUrl || ''}]]></NonLinearClickThrough>
          ${overlay.tracking ? `<TrackingEvents>${generateTrackingEvents(overlay.tracking)}</TrackingEvents>` : ''}
        </NonLinear>
      </NonLinearAds>
    </Creative>`
}

/**
 * Generate tracking events (impressions, quartiles, completion, etc.).
 */
function generateTrackingEvents(tracking) {
  const events = [
    { event: 'start', url: tracking.start },
    { event: 'firstQuartile', url: tracking.firstQuartile },
    { event: 'midpoint', url: tracking.midpoint },
    { event: 'thirdQuartile', url: tracking.thirdQuartile },
    { event: 'complete', url: tracking.complete },
    { event: 'mute', url: tracking.mute },
    { event: 'unmute', url: tracking.unmute },
    { event: 'pause', url: tracking.pause },
    { event: 'resume', url: tracking.resume },
    { event: 'rewind', url: tracking.rewind },
    { event: 'skip', url: tracking.skip },
    { event: 'playerExpand', url: tracking.expand },
    { event: 'playerCollapse', url: tracking.collapse },
    { event: 'acceptInvitation', url: tracking.acceptInvitation },
    { event: 'close', url: tracking.close },
    { event: 'progress', url: tracking.progress, offset: tracking.progressOffset }
  ]

  return events
    .filter(e => e.url)
    .map(e => {
      const offset = e.offset ? ` offset="${e.offset}"` : ''
      return `<Tracking event="${e.event}"${offset}><![CDATA[${e.url}]]></Tracking>`
    })
    .join('\n          ')
}

/**
 * Generate ad icons (e.g., "Ad" badge, skip button).
 */
function generateIcons(icons) {
  const iconElements = icons.map(icon => `
    <Icon program="${icon.program || 'AdChoices'}" width="${icon.width}" height="${icon.height}" 
          xPosition="${icon.x || 'right'}" yPosition="${icon.y || 'top'}" 
          offset="${formatDuration(icon.offset || 0)}" duration="${formatDuration(icon.duration || 0)}">
      <StaticResource creativeType="${icon.mimeType || 'image/png'}">
        <![CDATA[${icon.url}]]>
      </StaticResource>
      <IconClicks>
        <IconClickThrough><![CDATA[${icon.clickUrl || ''}]]></IconClickThrough>
      </IconClicks>
    </Icon>
  `).join('\n')

  return `<Icons>${iconElements}</Icons>`
}

/**
 * Generate pricing information.
 */
function generatePricing(pricing) {
  if (!pricing.model) return ''
  
  return `<Pricing model="${pricing.model}" currency="${pricing.currency || 'USD'}">
    <![CDATA[${pricing.price || '0.00'}]]>
  </Pricing>`
}

/**
 * Generate extensions (custom data).
 */
function generateExtensions(extensions) {
  if (!extensions || extensions.length === 0) return ''
  
  const extElements = extensions.map(ext => `
    <Extension type="${ext.type}">
      <![CDATA[${ext.value}]]>
    </Extension>
  `).join('\n')
  
  return `<Extensions>${extElements}</Extensions>`
}

/**
 * Format duration as HH:MM:SS.
 */
function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)
  
  return `${pad(hours)}:${pad(minutes)}:${pad(secs)}`
}

/**
 * Format skip offset (seconds or percentage).
 */
function formatSkipOffset(offset) {
  if (typeof offset === 'string' && offset.endsWith('%')) {
    return offset
  }
  return formatDuration(offset)
}

/**
 * Pad number with leading zero.
 */
function pad(num) {
  return num.toString().padStart(2, '0')
}

/**
 * Generate unique ad ID.
 */
function generateAdId() {
  return `ad-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
}

/**
 * Escape XML special characters.
 */
function escapeXml(str) {
  if (!str) return ''
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

/**
 * Parse VAST XML (for validation/testing).
 */
export function parseVAST(xml) {
  // Simple parser for testing - in production use a proper XML parser
  const adIdMatch = xml.match(/Ad id="([^"]+)"/)
  const impressionMatch = xml.match(/<Impression[^>]*><!\[CDATA\[([^\]]+)\]\]><\/Impression>/)
  const durationMatch = xml.match(/<Duration>([^<]+)<\/Duration>/)
  const clickThroughMatch = xml.match(/<ClickThrough><!\[CDATA\[([^\]]+)\]\]><\/ClickThrough>/)
  
  return {
    adId: adIdMatch ? adIdMatch[1] : null,
    impression: impressionMatch ? impressionMatch[1] : null,
    duration: durationMatch ? durationMatch[1] : null,
    clickThrough: clickThroughMatch ? clickThroughMatch[1] : null,
    isValid: xml.includes('<VAST') && xml.includes('</VAST>')
  }
}

/**
 * Validate VAST XML against IAB spec.
 */
export function validateVAST(xml) {
  const errors = []
  
  if (!xml.includes('<?xml version="1.0"')) {
    errors.push('Missing XML declaration')
  }
  
  if (!xml.includes('<VAST')) {
    errors.push('Missing VAST root element')
  }
  
  if (!xml.includes('version=')) {
    errors.push('Missing VAST version')
  }
  
  if (!xml.includes('<Ad ')) {
    errors.push('Missing Ad element')
  }
  
  if (!xml.includes('<Impression')) {
    errors.push('Missing Impression tracking')
  }
  
  if (!xml.includes('<Creative')) {
    errors.push('Missing Creative element')
  }
  
  return {
    isValid: errors.length === 0,
    errors
  }
}
