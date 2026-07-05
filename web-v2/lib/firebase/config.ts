// 🔥 FIREBASE CONFIGURATION - COMPLETE SETUP 💣

import { initializeApp, getApps, FirebaseApp } from 'firebase/app';
import { getAuth, Auth } from 'firebase/auth';
import { getFirestore, Firestore } from 'firebase/firestore';
import { getStorage, FirebaseStorage } from 'firebase/storage';
import { getDatabase, Database } from 'firebase/database';
import { getFunctions, Functions } from 'firebase/functions';

// Firebase configuration
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
  databaseURL: process.env.NEXT_PUBLIC_FIREBASE_DATABASE_URL, // For Realtime Database
};

// Initialize Firebase (singleton pattern)
let app: FirebaseApp;
let auth: Auth;
let firestore: Firestore;
let storage: FirebaseStorage;
let realtimeDb: Database;
// Cloud Functions callables live in the story-functions codebase (us-east1).
let functions: Functions;

if (typeof window !== 'undefined') {
  // Client-side initialization
  app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
  auth = getAuth(app);
  firestore = getFirestore(app);
  storage = getStorage(app);
  realtimeDb = getDatabase(app);
  functions = getFunctions(app, 'us-east1');

  console.log('✅ Firebase initialized (client-side)');
} else {
  // Server-side initialization (for API routes)
  app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
  auth = getAuth(app);
  firestore = getFirestore(app);
  storage = getStorage(app);
  realtimeDb = getDatabase(app);
  functions = getFunctions(app, 'us-east1');

  console.log('✅ Firebase initialized (server-side)');
}

// Export Firebase services
export { app, auth, firestore, storage, realtimeDb, functions };

// Alias for compatibility
export const db = firestore;
export const rtdb = realtimeDb;

// Firebase connection status
export function checkFirebaseConnection(): boolean {
  try {
    return !!app && !!firestore && !!auth;
  } catch (error) {
    console.error('🚨 Firebase connection check failed:', error);
    return false;
  }
}

// Initialize Firebase Analytics (client-side only)
export async function initializeAnalytics() {
  if (typeof window !== 'undefined' && process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID) {
    try {
      const { getAnalytics, logEvent } = await import('firebase/analytics');
      const analytics = getAnalytics(app);
      
      // Log initial page view
      logEvent(analytics, 'page_view', {
        page_title: document.title,
        page_location: window.location.href,
        page_path: window.location.pathname,
      });

      console.log('✅ Firebase Analytics initialized');
      return analytics;
    } catch (error) {
      console.error('🚨 Failed to initialize Analytics:', error);
      return null;
    }
  }
  return null;
}

// Firebase Performance Monitoring (client-side only)
export async function initializePerformance() {
  if (typeof window !== 'undefined') {
    try {
      const { getPerformance } = await import('firebase/performance');
      const performance = getPerformance(app);

      console.log('✅ Firebase Performance initialized');
      return performance;
    } catch (error) {
      console.error('🚨 Failed to initialize Performance:', error);
      return null;
    }
  }
  return null;
}

// Firebase Remote Config (for feature flags)
export async function initializeRemoteConfig() {
  if (typeof window !== 'undefined') {
    try {
      const { getRemoteConfig, fetchAndActivate } = await import('firebase/remote-config');
      const remoteConfig = getRemoteConfig(app);
      
      // Set default values
      remoteConfig.defaultConfig = {
        enable_ai_generation: true,
        enable_collaboration: true,
        enable_ab_testing: true,
        max_projects_per_user: 50,
        max_collaborators: 10,
      };

      // Fetch and activate
      await fetchAndActivate(remoteConfig);

      console.log('✅ Firebase Remote Config initialized');
      return remoteConfig;
    } catch (error) {
      console.error('🚨 Failed to initialize Remote Config:', error);
      return null;
    }
  }
  return null;
}

// Export initialization functions
export const initializeFirebaseServices = async () => {
  if (typeof window !== 'undefined') {
    await Promise.all([
      initializeAnalytics(),
      initializePerformance(),
      initializeRemoteConfig(),
    ]);
  }
};
