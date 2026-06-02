#!/usr/bin/env node

/**
 * Seed Live Shopping — populate the YouTube-style Live Shopping experience with
 * real, wired Firestore content so users see live shows, trending merch, flash
 * deals, creator shops, and dashboard metrics on day one (no client-side mocks).
 *
 * Schemas match what LiveShoppingService (iOS) reads:
 *   live_shopping_shows : isLive(bool), viewerCount(num desc), title, description,
 *                         thumbnailURL, creator{id,name,avatarURL}, startTime(ts),
 *                         featuredProducts[ids]
 *   shopping_products   : isActive(bool), reviews(num desc), isFlashSale(bool),
 *                         discount(num desc), name, description, price, originalPrice,
 *                         imageURL, category, creatorId, creatorCommission, rating,
 *                         hasARTryOn, stockRemaining, brand, storefrontURL
 *   creator_shops       : totalSales(num desc), creator{...}, productCount, rating,
 *                         creatorId, storefrontURL
 *   shopping_metrics/global : ordersToday, ordersTrend, avgOrderValue, avgOrderTrend,
 *                         liveViewers, liveViewersTrend, conversionRate, conversionTrend
 *
 * Usage:
 *   node scripts/seed-live-shopping.js --dry-run   # preview only
 *   node scripts/seed-live-shopping.js             # write to Firestore
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, '../firebase-service-account.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  console.log('✅ Firebase Admin initialized');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin');
  console.error('   Make sure firebase-service-account.json exists in the project root.');
  console.error('   Download from: https://console.firebase.google.com/project/mychannel-ca26d/settings/serviceaccounts/adminsdk');
  process.exit(1);
}

const db = admin.firestore();
const isDryRun = process.argv.includes('--dry-run');
const now = Date.now();
const ts = admin.firestore.Timestamp;

// NOTE: storefrontURL must point to the creator's OWN external store (Shopify,
// Fourthwall, etc.). Physical goods are purchased there — never via Apple IAP.
const OWNER_CREATOR = { id: 'sbkeonta_owner', name: 'Shot By Keonta', avatarURL: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg' };

const SHOWS = [
  {
    id: 'holiday-fashion-sale',
    title: 'Holiday Fashion Sale 🎄',
    description: 'Get ready for the holidays with amazing deals',
    thumbnailURL: '',
    creator: { id: 'fashion-queen', name: 'Fashion Queen', avatarURL: '' },
    viewerCount: 3456,
    featuredProducts: ['designer-sneakers', 'creator-hoodie'],
    isLive: true,
    startOffsetMin: -42,
  },
  {
    id: 'tech-drop-friday',
    title: 'Tech Drop Friday ⚡️',
    description: 'Fresh gadget drops + giveaways live',
    thumbnailURL: '',
    creator: { id: 'tech-guru', name: 'Tech Guru', avatarURL: '' },
    viewerCount: 1820,
    featuredProducts: ['wireless-headphones'],
    isLive: true,
    startOffsetMin: -15,
  },
];

const PRODUCTS = [
  {
    id: 'wireless-headphones',
    name: 'Premium Wireless Headphones',
    description: 'High-quality sound with active noise cancellation.',
    price: 199.99, originalPrice: 299, discount: 33,
    imageURL: '', category: 'tech', creatorId: 'tech-guru', creatorCommission: 15,
    rating: 4.8, reviews: 1234, hasARTryOn: false, stockRemaining: 45, brand: 'SoundPro',
    isActive: true, isFlashSale: true,
    storefrontURL: 'https://shop.mychannel.live/p/wireless-headphones',
  },
  {
    id: 'designer-sneakers',
    name: 'Designer Sneakers',
    description: 'Limited edition colorway, drops weekly.',
    price: 149.99, originalPrice: 200, discount: 25,
    imageURL: '', category: 'fashion', creatorId: 'fashion-queen', creatorCommission: 20,
    rating: 4.9, reviews: 567, hasARTryOn: true, stockRemaining: 12, brand: 'StepUp',
    isActive: true, isFlashSale: true,
    storefrontURL: 'https://shop.mychannel.live/p/designer-sneakers',
  },
  {
    id: 'creator-hoodie',
    name: 'Signature Creator Hoodie',
    description: 'Heavyweight cotton, embroidered logo.',
    price: 59.99, originalPrice: 80, discount: 25,
    imageURL: '', category: 'fashion', creatorId: 'sbkeonta_owner', creatorCommission: 30,
    rating: 4.7, reviews: 892, hasARTryOn: true, stockRemaining: 60, brand: 'Shot By Keonta',
    isActive: true, isFlashSale: true,
    storefrontURL: 'https://shop.mychannel.live/p/creator-hoodie',
  },
  {
    id: 'logo-tee',
    name: 'Classic Logo Tee',
    description: 'Soft tri-blend tee with front logo print.',
    price: 34.99, originalPrice: 45, discount: 22,
    imageURL: '', category: 'fashion', creatorId: 'sbkeonta_owner', creatorCommission: 30,
    rating: 4.6, reviews: 410, hasARTryOn: true, stockRemaining: 120, brand: 'Shot By Keonta',
    isActive: true, isFlashSale: false,
    storefrontURL: 'https://shop.mychannel.live/p/logo-tee',
  },
  {
    id: 'snapback-cap',
    name: 'Embroidered Snapback Cap',
    description: 'Structured 6-panel cap, adjustable snap.',
    price: 29.99, originalPrice: 35, discount: 14,
    imageURL: '', category: 'fashion', creatorId: 'sbkeonta_owner', creatorCommission: 30,
    rating: 4.5, reviews: 233, hasARTryOn: false, stockRemaining: 80, brand: 'Shot By Keonta',
    isActive: true, isFlashSale: false,
    storefrontURL: 'https://shop.mychannel.live/p/snapback-cap',
  },
  {
    id: 'glow-serum',
    name: 'Daily Glow Serum',
    description: 'Vitamin C brightening serum, cruelty-free.',
    price: 24.0, originalPrice: 32, discount: 25,
    imageURL: '', category: 'beauty', creatorId: 'fashion-queen', creatorCommission: 18,
    rating: 4.8, reviews: 1502, hasARTryOn: false, stockRemaining: 34, brand: 'Lumen',
    isActive: true, isFlashSale: true,
    storefrontURL: 'https://shop.mychannel.live/p/glow-serum',
  },
];

const SHOPS = [
  {
    id: 'tech-guru', creator: { id: 'tech-guru', name: 'Tech Guru', avatarURL: '' },
    creatorId: 'tech-guru', productCount: 45, totalSales: 12500, rating: 4.9,
    storefrontURL: 'https://shop.mychannel.live/tech-guru',
  },
  {
    id: 'fashion-queen', creator: { id: 'fashion-queen', name: 'Fashion Queen', avatarURL: '' },
    creatorId: 'fashion-queen', productCount: 78, totalSales: 28400, rating: 4.8,
    storefrontURL: 'https://shop.mychannel.live/fashion-queen',
  },
  {
    id: 'sbkeonta_owner', creator: OWNER_CREATOR,
    creatorId: 'sbkeonta_owner', productCount: 16, totalSales: 9100, rating: 5.0,
    storefrontURL: 'https://shop.mychannel.live/shotbykeonta',
  },
];

const METRICS = {
  ordersToday: '12.4K', ordersTrend: '+18% vs yesterday',
  avgOrderValue: '$86.20', avgOrderTrend: '+4.5% week over week',
  liveViewers: '35.8K', liveViewersTrend: '+9% last hour',
  conversionRate: '7.2%', conversionTrend: '+0.8 pts today',
};

async function seed() {
  console.log(`🌱 Seeding live shopping${isDryRun ? ' (DRY RUN)' : ''}...`);

  for (const s of SHOWS) {
    const doc = {
      title: s.title, description: s.description, thumbnailURL: s.thumbnailURL,
      creator: s.creator, viewerCount: s.viewerCount, featuredProducts: s.featuredProducts,
      isLive: s.isLive, startTime: ts.fromDate(new Date(now + s.startOffsetMin * 60 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (isDryRun) { console.log(`   [dry-run] live_shopping_shows/${s.id}`, { title: doc.title, isLive: doc.isLive }); }
    else { await db.collection('live_shopping_shows').doc(s.id).set(doc, { merge: true }); console.log(`   ✅ live_shopping_shows/${s.id} — ${s.title}`); }
  }

  for (const p of PRODUCTS) {
    const doc = {
      name: p.name, description: p.description, price: p.price, originalPrice: p.originalPrice,
      discount: p.discount, imageURL: p.imageURL, category: p.category, creatorId: p.creatorId,
      creatorCommission: p.creatorCommission, rating: p.rating, reviews: p.reviews,
      hasARTryOn: p.hasARTryOn, stockRemaining: p.stockRemaining, brand: p.brand,
      isActive: p.isActive, isFlashSale: p.isFlashSale, storefrontURL: p.storefrontURL,
      views: 0, checkoutTaps: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (isDryRun) { console.log(`   [dry-run] shopping_products/${p.id}`, { name: doc.name, flash: doc.isFlashSale }); }
    else { await db.collection('shopping_products').doc(p.id).set(doc, { merge: true }); console.log(`   ✅ shopping_products/${p.id} — ${p.name}`); }
  }

  for (const shop of SHOPS) {
    const doc = {
      creator: shop.creator, creatorId: shop.creatorId, productCount: shop.productCount,
      totalSales: shop.totalSales, rating: shop.rating, storefrontURL: shop.storefrontURL,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (isDryRun) { console.log(`   [dry-run] creator_shops/${shop.id}`, { sales: doc.totalSales }); }
    else { await db.collection('creator_shops').doc(shop.id).set(doc, { merge: true }); console.log(`   ✅ creator_shops/${shop.id} — ${shop.creator.name}`); }
  }

  const metricsDoc = { ...METRICS, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (isDryRun) { console.log('   [dry-run] shopping_metrics/global', METRICS); }
  else { await db.collection('shopping_metrics').doc('global').set(metricsDoc, { merge: true }); console.log('   ✅ shopping_metrics/global'); }

  console.log('🏁 Done.');
}

seed().then(() => process.exit(0)).catch((err) => { console.error('❌ Seed failed:', err); process.exit(1); });
