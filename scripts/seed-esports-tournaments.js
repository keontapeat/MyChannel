#!/usr/bin/env node

/**
 * Seed Esports Tournaments - Populate the Gaming & Esports Arena with real,
 * joinable tournaments so users see live content on day one (instead of the
 * client-side sample fallback).
 *
 * The document schema matches what EsportsTournamentService reads:
 *   - status in ["active","upcoming","live"]   (queried)
 *   - startDate (Timestamp, ordered ascending)
 *   - prizePool (Number, ordered descending for the featured pick)
 *   - name, gameName, entryFee, format, currentPlayers, maxPlayers, isLive
 *
 * Usage:
 *   node scripts/seed-esports-tournaments.js --dry-run   # preview only
 *   node scripts/seed-esports-tournaments.js             # write to Firestore
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../firebase-service-account.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin initialized');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin');
  console.error('   Make sure firebase-service-account.json exists in the project root');
  console.error('   Download it from: https://console.firebase.google.com/project/mychannel-ca26d/settings/serviceaccounts/adminsdk');
  process.exit(1);
}

const db = admin.firestore();
const isDryRun = process.argv.includes('--dry-run');
const HOUR = 60 * 60 * 1000;
const now = Date.now();

const TOURNAMENTS = [
  {
    id: 'spring-championship',
    name: 'Spring Championship',
    gameName: 'Multi-Game',
    prizePool: 50000,
    entryFee: 50,
    format: 'Single Elimination',
    currentPlayers: 248,
    maxPlayers: 256,
    startOffsetHours: 38,
    isLive: false,
    status: 'upcoming',
  },
  {
    id: 'pro-league-finals',
    name: 'Pro League Finals',
    gameName: 'Fortnite',
    prizePool: 75000,
    entryFee: 100,
    format: 'Single Elimination',
    currentPlayers: 96,
    maxPlayers: 128,
    startOffsetHours: 125,
    isLive: false,
    status: 'upcoming',
  },
  {
    id: 'masters-valorant',
    name: 'Masters Tournament',
    gameName: 'Valorant',
    prizePool: 100000,
    entryFee: 150,
    format: 'Double Elimination',
    currentPlayers: 180,
    maxPlayers: 256,
    startOffsetHours: -2, // already started
    isLive: true,
    status: 'live',
  },
  {
    id: 'rookie-rumble',
    name: 'Rookie Rumble',
    gameName: 'Rocket League',
    prizePool: 5000,
    entryFee: 10,
    format: 'Single Elimination',
    currentPlayers: 40,
    maxPlayers: 64,
    startOffsetHours: 12,
    isLive: false,
    status: 'active',
  },
];

async function seed() {
  console.log(`🌱 Seeding ${TOURNAMENTS.length} tournaments${isDryRun ? ' (DRY RUN)' : ''}...`);

  for (const t of TOURNAMENTS) {
    const startDate = new Date(now + t.startOffsetHours * HOUR);
    const endDate = new Date(startDate.getTime() + 7 * 24 * HOUR);

    const doc = {
      name: t.name,
      gameName: t.gameName,
      prizePool: t.prizePool,
      entryFee: t.entryFee,
      format: t.format,
      currentPlayers: t.currentPlayers,
      maxPlayers: t.maxPlayers,
      maxParticipants: t.maxPlayers,
      isLive: t.isLive,
      status: t.status,
      category: 'gaming',
      startDate: admin.firestore.Timestamp.fromDate(startDate),
      startTime: admin.firestore.Timestamp.fromDate(startDate),
      endDate: admin.firestore.Timestamp.fromDate(endDate),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (isDryRun) {
      console.log(`   [dry-run] tournaments/${t.id}:`, {
        name: doc.name, status: doc.status, prizePool: doc.prizePool, startDate: startDate.toISOString(),
      });
      continue;
    }

    await db.collection('tournaments').doc(t.id).set(doc, { merge: true });
    console.log(`   ✅ tournaments/${t.id} — ${t.name} ($${t.prizePool.toLocaleString()})`);
  }

  console.log('🏁 Done.');
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  });
