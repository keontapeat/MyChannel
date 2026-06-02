import { generateVAST, parseVAST, validateVAST } from '../src/vast/vast-generator.js'
import { generateVPAID, validateVPAID, VPAID_EVENTS } from '../src/vast/vpaid-wrapper.js'
import { AD_FORMATS, validateCreative, calculateBilling } from '../src/formats/video-ad-formats.js'
import assert from 'assert'

let pass = 0
function ok(name, cond) { 
  assert.ok(cond, name)
  console.log('  ✓ ' + name)
  pass++ 
}

console.log('VAST/VPAID & Video Formats Tests:\n')

// VAST Tests
console.log('VAST 4.2 Generation:')

const mockAd = {
  id: 'test-ad-123',
  title: 'Test Video Ad',
  description: 'A test advertisement',
  advertiser: 'Test Advertiser',
  type: 'video',
  uri: 'https://example.com/ad.mp4',
  click_url: 'https://example.com/click',
  duration_sec: 30,
  width: 1920,
  height: 1080
}

const mockTracking = {
  impression: 'https://example.com/track/impression',
  start: 'https://example.com/track/start',
  firstQuartile: 'https://example.com/track/q1',
  midpoint: 'https://example.com/track/mid',
  thirdQuartile: 'https://example.com/track/q3',
  complete: 'https://example.com/track/complete',
  click: 'https://example.com/track/click'
}

const vastXml = generateVAST(mockAd, mockTracking)

ok('VAST XML generated', vastXml.length > 0)
ok('VAST has XML declaration', vastXml.includes('<?xml version="1.0"'))
ok('VAST has root element', vastXml.includes('<VAST version="4.2"'))
ok('VAST has Ad element', vastXml.includes('<Ad id="test-ad-123"'))
ok('VAST has impression tracking', vastXml.includes('<Impression'))
ok('VAST has creative', vastXml.includes('<Creative'))
ok('VAST has video file', vastXml.includes('https://example.com/ad.mp4'))

const parsed = parseVAST(vastXml)
ok('VAST parses correctly', parsed.isValid)
ok('Parsed ad ID matches', parsed.adId === 'test-ad-123')

const validation = validateVAST(vastXml)
ok('VAST validates successfully', validation.isValid)

// VPAID Tests
console.log('\nVPAID 2.0 Generation:')

const vpaidCode = generateVPAID(mockAd, { tracking: mockTracking })

ok('VPAID code generated', vpaidCode.length > 0)
ok('VPAID has handshakeVersion', vpaidCode.includes('handshakeVersion'))
ok('VPAID has initAd', vpaidCode.includes('initAd'))
ok('VPAID has startAd', vpaidCode.includes('startAd'))
ok('VPAID has stopAd', vpaidCode.includes('stopAd'))
ok('VPAID has getVPAIDAd', vpaidCode.includes('getVPAIDAd'))

const vpaidValidation = validateVPAID(vpaidCode)
ok('VPAID validates successfully', vpaidValidation.isValid)

ok('VPAID events defined', Object.keys(VPAID_EVENTS).length > 0)
ok('VPAID has AdLoaded event', VPAID_EVENTS.AdLoaded === 'AdLoaded')

// Video Format Tests
console.log('\nVideo Ad Formats:')

ok('Skippable format exists', AD_FORMATS.SKIPPABLE_INSTREAM !== undefined)
ok('Non-skippable format exists', AD_FORMATS.NON_SKIPPABLE_INSTREAM !== undefined)
ok('Bumper format exists', AD_FORMATS.BUMPER !== undefined)
ok('Overlay format exists', AD_FORMATS.OVERLAY !== undefined)
ok('Mid-roll format exists', AD_FORMATS.MID_ROLL !== undefined)
ok('Masthead format exists', AD_FORMATS.MASTHEAD !== undefined)

const skippableFormat = AD_FORMATS.SKIPPABLE_INSTREAM
ok('Skippable is skippable', skippableFormat.skippable === true)
ok('Skippable skip after 5s', skippableFormat.skipAfter === 5)
ok('Skippable billing is CPV', skippableFormat.billingEvent === 'view_30s_or_complete')

const bumperFormat = AD_FORMATS.BUMPER
ok('Bumper is 6 seconds', bumperFormat.maxDuration === 6)
ok('Bumper is not skippable', bumperFormat.skippable === false)

// Creative Validation
console.log('\nCreative Validation:')

const validCreative = {
  duration: 30,
  width: 1920,
  height: 1080,
  fileSize: 50 * 1024 * 1024,
  bitrate: 2000,
  videoCodec: 'H.264'
}

const validation1 = validateCreative(validCreative, 'SKIPPABLE_INSTREAM')
ok('Valid creative passes', validation1.isValid)

const tooShort = { ...validCreative, duration: 5 }
const validation2 = validateCreative(tooShort, 'SKIPPABLE_INSTREAM')
ok('Too short creative fails', !validation2.isValid)

const tooLarge = { ...validCreative, fileSize: 2 * 1024 * 1024 * 1024 }
const validation3 = validateCreative(tooLarge, 'SKIPPABLE_INSTREAM')
ok('Too large creative fails', !validation3.isValid)

// Billing Tests
console.log('\nBilling Calculation:')

const billing1 = calculateBilling('SKIPPABLE_INSTREAM', 35, false, { cpv: 0.10 })
ok('30s+ view is billable', billing1.billable === true)
ok('Billing amount correct', billing1.amount === 0.10)

const billing2 = calculateBilling('SKIPPABLE_INSTREAM', 10, false, { cpv: 0.10 })
ok('Short view not billable', billing2.billable === false)

const billing3 = calculateBilling('BUMPER', 6, false, { cpm: 5.00 })
ok('Bumper impression billable', billing3.billable === true)

const billing4 = calculateBilling('OVERLAY', 0, true, { cpc: 0.50 })
ok('Overlay click billable', billing4.billable === true)
ok('Click amount correct', billing4.amount === 0.50)

console.log('\n' + '='.repeat(60))
console.log(`ALL VAST/VPAID/FORMAT TESTS PASSED (${pass})`)
console.log('='.repeat(60))

console.log('\n✅ YouTube-Level Ad Serving:')
console.log('  • VAST 4.2 XML generation')
console.log('  • VPAID 2.0 JavaScript wrapper')
console.log('  • 6 video ad formats (YouTube standard)')
console.log('  • Creative validation')
console.log('  • Billing calculation')
console.log('  • Industry standard compliance')
