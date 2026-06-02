import crypto from 'crypto'

// pub-XXXXXXXXXXXXXXXX (16 digits) — mirrors AdSense publisher IDs
export function newPublisherCode() {
  let n = ''
  for (let i = 0; i < 16; i++) n += Math.floor(Math.random() * 10)
  return `pub-${n}`
}

// numeric data-ad-slot value
export function newSlotId() {
  let n = ''
  for (let i = 0; i < 10; i++) n += Math.floor(Math.random() * 10)
  return n
}

export function newApiKey() {
  return 'mca_' + crypto.randomBytes(24).toString('hex')
}

export function newToken(prefix = 'mca') {
  return `${prefix}-${crypto.randomBytes(8).toString('hex')}`
}

export function hashIp(ip = '') {
  return crypto.createHash('sha256').update(String(ip)).digest('hex').slice(0, 32)
}

export function hashUa(ua = '') {
  return crypto.createHash('md5').update(String(ua)).digest('hex')
}
