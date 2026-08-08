// 🔥 THERMONUCLEAR: Optimized Firestore Operations for Web
// Cache-first strategy + batch operations (mirrors iOS VideoFirestoreService)

import { 
  collection, 
  query, 
  where, 
  orderBy, 
  limit, 
  getDocs, 
  writeBatch,
  doc,
  getDoc,
  DocumentData,
  QueryConstraint,
  getDocsFromCache,
  getDocsFromServer
} from 'firebase/firestore';
import { db } from './config';
import { appendVideoEngagement } from './video-engagement';
import { performanceMonitor } from '../performance/PerformanceMonitor';

export class FirestoreOptimized {
  
  /**
   * 🔥 THERMONUCLEAR: Fetch with cache-first strategy
   * Tries cache first for instant loads, then fetches from server
   */
  static async fetchWithCacheFirst<T>(
    collectionName: string,
    constraints: QueryConstraint[] = [],
    transform: (data: DocumentData) => T
  ): Promise<T[]> {
    const startTime = performance.now();
    
    try {
      // 1. Try cache first (INSTANT!)
      const q = query(collection(db, collectionName), ...constraints);
      
      try {
        const cachedSnapshot = await getDocsFromCache(q);
        const cachedData = cachedSnapshot.docs.map(doc => transform(doc.data()));
        
        if (cachedData.length > 0) {
          const duration = performance.now() - startTime;
          performanceMonitor.measureNetworkRequest(collectionName, duration, true);
          console.log(`⚡ [Firestore] Loaded ${cachedData.length} from cache (${duration.toFixed(0)}ms)`);
          return cachedData;
        }
      } catch (cacheError) {
        // Cache miss, fall through to server fetch
      }
      
      // 2. Fetch from server
      const serverSnapshot = await getDocsFromServer(q);
      const serverData = serverSnapshot.docs.map(doc => transform(doc.data()));
      
      const duration = performance.now() - startTime;
      performanceMonitor.measureNetworkRequest(collectionName, duration, false);
      console.log(`✅ [Firestore] Loaded ${serverData.length} from server (${duration.toFixed(0)}ms)`);
      
      return serverData;
      
    } catch (error) {
      console.error(`🚨 [Firestore] Error fetching ${collectionName}:`, error);
      return [];
    }
  }

  /**
   * 🔥 THERMONUCLEAR: Batch write operations (500 at once)
   * 10x faster than individual writes
   */
  static async batchWrite(
    operations: Array<{
      collection: string;
      id: string;
      data: any;
      operation: 'set' | 'update' | 'delete';
    }>
  ): Promise<void> {
    const startTime = performance.now();
    const batch = writeBatch(db);
    
    // Firestore limit: 500 operations per batch
    const opsToProcess = operations.slice(0, 500);
    
    opsToProcess.forEach(op => {
      const docRef = doc(db, op.collection, op.id);
      
      switch (op.operation) {
        case 'set':
          batch.set(docRef, op.data, { merge: true });
          break;
        case 'update':
          batch.update(docRef, op.data);
          break;
        case 'delete':
          batch.delete(docRef);
          break;
      }
    });
    
    await batch.commit();
    
    const duration = performance.now() - startTime;
    console.log(`✅ [Firestore] Batch operation: ${opsToProcess.length} ops in ${duration.toFixed(0)}ms`);
  }

  /**
   * Batch immutable view facts. The server applies identity, session and cooldown
   * semantics before changing public counters.
   */
  static async incrementViewCounts(videoIds: string[]): Promise<void> {
    const batch = writeBatch(db);
    [...new Set(videoIds)].slice(0, 250).forEach(videoId => {
      appendVideoEngagement(batch, videoId, 'view');
    });
    await batch.commit();
  }

  /**
   * 🔥 THERMONUCLEAR: Parallel fetch multiple documents
   */
  static async fetchMultiple<T>(
    collectionName: string,
    ids: string[],
    transform: (data: DocumentData) => T
  ): Promise<T[]> {
    const startTime = performance.now();
    
    // Fetch all in parallel (much faster than sequential)
    const promises = ids.map(id => 
      getDoc(doc(db, collectionName, id))
    );
    
    const snapshots = await Promise.all(promises);
    const results = snapshots
      .filter(snap => snap.exists())
      .map(snap => transform(snap.data()!));
    
    const duration = performance.now() - startTime;
    console.log(`✅ [Firestore] Parallel fetch: ${results.length} docs in ${duration.toFixed(0)}ms`);
    
    return results;
  }
}

export default FirestoreOptimized;

