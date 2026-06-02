#!/usr/bin/env node
/**
 * Seed Live Shopping via the Firestore REST API using the Firebase CLI's stored
 * OAuth access token. No firebase-admin / service-account file required.
 *
 *   node scripts/seed-live-shopping-rest.cjs --dry-run
 *   node scripts/seed-live-shopping-rest.cjs
 *
 * Reuses the same documents/schema as scripts/seed-live-shopping.js so the iOS
 * LiveShoppingService reads real, wired content.
 */

const os = require('os');
const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT = 'mychannel-ca26d';
const isDryRun = process.argv.includes('--dry-run');

// --- Load the Firebase CLI access token --------------------------------------
function loadToken() {
  const f = path.join(os.homedir(), '.config/configstore/firebase-tools.json');
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  const t = j.tokens || {};
  if (t.access_token && t.expires_at && t.expires_at > Date.now() + 60000) {
    return Promise.resolve(t.access_token);
  }
  if (!t.refresh_token) throw new Error('No usable Firebase CLI token. Run: firebase login');
  // Refresh using the firebase-tools public client id.
  const body = new URLSearchParams({
    refresh_token: t.refresh_token,
    grant_type: 'refresh_token',
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
  }).toString();
  return httpRequest('oauth2.googleapis.com', '/token', 'POST', null, body,
    'application/x-www-form-urlencoded').then((r) => JSON.parse(r).access_token);
}

function httpRequest(host, p, method, token, body, contentType) {
  return new Promise((resolve, reject) => {
    const headers = {};
    if (token) headers['Authorization'] = 'Bearer ' + token;
    if (body) {
      headers['Content-Type'] = contentType || 'application/json';
      headers['Content-Length'] = Buffer.byteLength(body);
    }
    const req = https.request({ host, path: p, method, headers }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve(data);
        else reject(new Error(`${res.statusCode} ${p}: ${data}`));
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// --- Firestore REST value encoding -------------------------------------------
function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (typeof v === 'object') {
    const fields = {};
    for (const k of Object.keys(v)) fields[k] = toValue(v[k]);
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

function toFields(obj) {
  const fields = {};
  for (const k of Object.keys(obj)) fields[k] = toValue(obj[k]);
  return fields;
}

async function setDoc(token, collection, id, data) {
  const p = `/v1/projects/${PROJECT}/databases/(default)/documents/${collection}/${encodeURIComponent(id)}`;
  if (isDryRun) { console.log(`   [dry-run] ${collection}/${id}`); return; }
  await httpRequest('firestore.googleapis.com', p, 'PATCH', token, JSON.stringify({ fields: toFields(data) }));
  console.log(`   ✅ ${collection}/${id}`);
}

// --- Data --------------------------------------------------------------------
const now = Date.now();
const OWNER = { id: 'sbkeonta_owner', name: 'Shot By Keonta', avatarURL: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg' };

const SHOWS = [
  { id: 'holiday-fashion-sale', title: 'Holiday Fashion Sale 🎄', description: 'Get ready for the holidays with amazing deals', thumbnailURL: '', creator: { id: 'fashion-queen', name: 'Fashion Queen', avatarURL: '' }, viewerCount: 3456, featuredProducts: ['designer-sneakers', 'creator-hoodie'], isLive: true, startOffsetMin: -42 },
  { id: 'tech-drop-friday', title: 'Tech Drop Friday ⚡️', description: 'Fresh gadget drops + giveaways live', thumbnailURL: '', creator: { id: 'tech-guru', name: 'Tech Guru', avatarURL: '' }, viewerCount: 1820, featuredProducts: ['wireless-headphones'], isLive: true, startOffsetMin: -15 },
];

const PRODUCTS = [
  { id: 'wireless-headphones', name: 'Premium Wireless Headphones', description: 'High-quality sound with active noise cancellation.', price: 199.99, originalPrice: 299, discount: 33, imageURL: '', category: 'tech', creatorId: 'tech-guru', creatorCommission: 15, rating: 4.8, reviews: 1234, hasARTryOn: false, stockRemaining: 45, brand: 'SoundPro', isActive: true, isFlashSale: true, storefrontURL: 'https://shop.mychannel.live/p/wireless-headphones' },
  { id: 'designer-sneakers', name: 'Designer Sneakers', description: 'Limited edition colorway, drops weekly.', price: 149.99, originalPrice: 200, discount: 25, imageURL: '', category: 'fashion', creatorId: 'fashion-queen', creatorCommission: 20, rating: 4.9, reviews: 567, hasARTryOn: true, stockRemaining: 12, brand: 'StepUp', isActive: true, isFlashSale: true, storefrontURL: 'https://shop.mychannel.live/p/designer-sneakers' },
  { id: 'creator-hoodie', name: 'Signature Creator Hoodie', description: 'Heavyweight cotton, embroidered logo.', price: 59.99, originalPrice: 80, discount: 25, imageURL: '', category: 'fashion', creatorId: 'sbkeonta_owner', creatorCommission: 30, rating: 4.7, reviews: 892, hasARTryOn: true, stockRemaining: 60, brand: 'Shot By Keonta', isActive: true, isFlashSale: true, storefrontURL: 'https://shop.mychannel.live/p/creator-hoodie' },
  { id: 'logo-tee', name: 'Classic Logo Tee', description: 'Soft tri-blend tee with front logo print.', price: 34.99, originalPrice: 45, discount: 22, imageURL: '', category: 'fashion', creatorId: 'sbkeonta_owner', creatorCommission: 30, rating: 4.6, reviews: 410, hasARTryOn: true, stockRemaining: 120, brand: 'Shot By Keonta', isActive: true, isFlashSale: false, storefrontURL: 'https://shop.mychannel.live/p/logo-tee' },
  { id: 'snapback-cap', name: 'Embroidered Snapback Cap', description: 'Structured 6-panel cap, adjustable snap.', price: 29.99, originalPrice: 35, discount: 14, imageURL: '', category: 'fashion', creatorId: 'sbkeonta_owner', creatorCommission: 30, rating: 4.5, reviews: 233, hasARTryOn: false, stockRemaining: 80, brand: 'Shot By Keonta', isActive: true, isFlashSale: false, storefrontURL: 'https://shop.mychannel.live/p/snapback-cap' },
  { id: 'glow-serum', name: 'Daily Glow Serum', description: 'Vitamin C brightening serum, cruelty-free.', price: 24.0, originalPrice: 32, discount: 25, imageURL: '', category: 'beauty', creatorId: 'fashion-queen', creatorCommission: 18, rating: 4.8, reviews: 1502, hasARTryOn: false, stockRemaining: 34, brand: 'Lumen', isActive: true, isFlashSale: true, storefrontURL: 'https://shop.mychannel.live/p/glow-serum' },
];

const SHOPS = [
  { id: 'tech-guru', creator: { id: 'tech-guru', name: 'Tech Guru', avatarURL: '' }, creatorId: 'tech-guru', productCount: 45, totalSales: 12500, rating: 4.9, storefrontURL: 'https://shop.mychannel.live/tech-guru' },
  { id: 'fashion-queen', creator: { id: 'fashion-queen', name: 'Fashion Queen', avatarURL: '' }, creatorId: 'fashion-queen', productCount: 78, totalSales: 28400, rating: 4.8, storefrontURL: 'https://shop.mychannel.live/fashion-queen' },
  { id: 'sbkeonta_owner', creator: OWNER, creatorId: 'sbkeonta_owner', productCount: 16, totalSales: 9100, rating: 5.0, storefrontURL: 'https://shop.mychannel.live/shotbykeonta' },
];

const METRICS = { ordersToday: '12.4K', ordersTrend: '+18% vs yesterday', avgOrderValue: '$86.20', avgOrderTrend: '+4.5% week over week', liveViewers: '35.8K', liveViewersTrend: '+9% last hour', conversionRate: '7.2%', conversionTrend: '+0.8 pts today' };

async function main() {
  console.log(`🌱 Seeding live shopping via REST${isDryRun ? ' (DRY RUN)' : ''}...`);
  const token = await loadToken();

  for (const s of SHOWS) {
    await setDoc(token, 'live_shopping_shows', s.id, {
      title: s.title, description: s.description, thumbnailURL: s.thumbnailURL, creator: s.creator,
      viewerCount: s.viewerCount, featuredProducts: s.featuredProducts, isLive: s.isLive,
      startTime: new Date(now + s.startOffsetMin * 60000),
    });
  }
  for (const p of PRODUCTS) {
    const { id, ...rest } = p;
    await setDoc(token, 'shopping_products', id, { ...rest, views: 0, checkoutTaps: 0 });
  }
  for (const shop of SHOPS) {
    const { id, ...rest } = shop;
    await setDoc(token, 'creator_shops', id, rest);
  }
  await setDoc(token, 'shopping_metrics', 'global', METRICS);

  console.log('🏁 Done.');
}

main().catch((e) => { console.error('❌ Seed failed:', e.message); process.exit(1); });
