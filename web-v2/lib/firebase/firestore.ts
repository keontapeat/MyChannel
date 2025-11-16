// Firestore Helper Utilities for MyChannel Web

import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  startAfter,
  QueryConstraint,
  DocumentData,
  QueryDocumentSnapshot,
  Timestamp,
  FieldValue,
  increment as firestoreIncrement,
  arrayUnion,
  arrayRemove,
  serverTimestamp,
} from 'firebase/firestore';
import { firestore } from './config';

export class FirestoreService {
  // Get document by ID
  static async getDocument<T = DocumentData>(
    collectionName: string,
    documentId: string
  ): Promise<T | null> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      const docSnap = await getDoc(docRef);

      if (docSnap.exists()) {
        return this.convertTimestamps({
          id: docSnap.id,
          ...docSnap.data(),
        }) as T;
      }

      return null;
    } catch (error) {
      console.error('🚨 Get document error:', error);
      throw error;
    }
  }

  // Get multiple documents with query
  static async getDocuments<T = DocumentData>(
    collectionName: string,
    constraints: QueryConstraint[] = []
  ): Promise<T[]> {
    try {
      const collectionRef = collection(firestore, collectionName);
      const q = query(collectionRef, ...constraints);
      const querySnapshot = await getDocs(q);

      return querySnapshot.docs.map((doc) =>
        this.convertTimestamps({
          id: doc.id,
          ...doc.data(),
        })
      ) as T[];
    } catch (error) {
      console.error('🚨 Get documents error:', error);
      throw error;
    }
  }

  // Set document (create or overwrite)
  static async setDocument<T extends DocumentData>(
    collectionName: string,
    documentId: string,
    data: T
  ): Promise<void> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      await setDoc(docRef, this.prepareDataForFirestore(data));
      console.log(`✅ Document set: ${collectionName}/${documentId}`);
    } catch (error) {
      console.error('🚨 Set document error:', error);
      throw error;
    }
  }

  // Update document (merge)
  static async updateDocument(
    collectionName: string,
    documentId: string,
    data: Partial<DocumentData>
  ): Promise<void> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      await updateDoc(docRef, this.prepareDataForFirestore(data));
      console.log(`✅ Document updated: ${collectionName}/${documentId}`);
    } catch (error) {
      console.error('🚨 Update document error:', error);
      throw error;
    }
  }

  // Delete document
  static async deleteDocument(
    collectionName: string,
    documentId: string
  ): Promise<void> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      await deleteDoc(docRef);
      console.log(`✅ Document deleted: ${collectionName}/${documentId}`);
    } catch (error) {
      console.error('🚨 Delete document error:', error);
      throw error;
    }
  }

  // Increment field value
  static async incrementField(
    collectionName: string,
    documentId: string,
    fieldName: string,
    incrementBy: number = 1
  ): Promise<void> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      await updateDoc(docRef, {
        [fieldName]: firestoreIncrement(incrementBy),
      });
      console.log(
        `✅ Field incremented: ${collectionName}/${documentId}/${fieldName} by ${incrementBy}`
      );
    } catch (error) {
      console.error('🚨 Increment field error:', error);
      throw error;
    }
  }

  // Add to array field
  static async addToArray(
    collectionName: string,
    documentId: string,
    fieldName: string,
    value: any
  ): Promise<void> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      await updateDoc(docRef, {
        [fieldName]: arrayUnion(value),
      });
      console.log(
        `✅ Added to array: ${collectionName}/${documentId}/${fieldName}`
      );
    } catch (error) {
      console.error('🚨 Add to array error:', error);
      throw error;
    }
  }

  // Remove from array field
  static async removeFromArray(
    collectionName: string,
    documentId: string,
    fieldName: string,
    value: any
  ): Promise<void> {
    try {
      const docRef = doc(firestore, collectionName, documentId);
      await updateDoc(docRef, {
        [fieldName]: arrayRemove(value),
      });
      console.log(
        `✅ Removed from array: ${collectionName}/${documentId}/${fieldName}`
      );
    } catch (error) {
      console.error('🚨 Remove from array error:', error);
      throw error;
    }
  }

  // Pagination helper
  static async getDocumentsWithPagination<T = DocumentData>(
    collectionName: string,
    pageSize: number = 20,
    lastDoc?: QueryDocumentSnapshot,
    constraints: QueryConstraint[] = []
  ): Promise<{ docs: T[]; lastDoc: QueryDocumentSnapshot | null }> {
    try {
      const collectionRef = collection(firestore, collectionName);
      const queryConstraints = [...constraints, limit(pageSize)];

      if (lastDoc) {
        queryConstraints.push(startAfter(lastDoc));
      }

      const q = query(collectionRef, ...queryConstraints);
      const querySnapshot = await getDocs(q);

      const docs = querySnapshot.docs.map((doc) =>
        this.convertTimestamps({
          id: doc.id,
          ...doc.data(),
        })
      ) as T[];

      const newLastDoc =
        querySnapshot.docs[querySnapshot.docs.length - 1] || null;

      return { docs, lastDoc: newLastDoc };
    } catch (error) {
      console.error('🚨 Get documents with pagination error:', error);
      throw error;
    }
  }

  // Convert Firestore Timestamps to JavaScript Dates
  private static convertTimestamps(data: any): any {
    if (!data) return data;

    if (data instanceof Timestamp) {
      return data.toDate();
    }

    if (Array.isArray(data)) {
      return data.map((item) => this.convertTimestamps(item));
    }

    if (typeof data === 'object') {
      const converted: any = {};
      for (const key in data) {
        converted[key] = this.convertTimestamps(data[key]);
      }
      return converted;
    }

    return data;
  }

  // Prepare data for Firestore (convert Dates to Timestamps)
  private static prepareDataForFirestore(data: any): any {
    if (!data) return data;

    if (data instanceof Date) {
      return Timestamp.fromDate(data);
    }

    if (Array.isArray(data)) {
      return data.map((item) => this.prepareDataForFirestore(item));
    }

    if (typeof data === 'object') {
      const prepared: any = {};
      for (const key in data) {
        // Skip undefined values
        if (data[key] !== undefined) {
          prepared[key] = this.prepareDataForFirestore(data[key]);
        }
      }
      return prepared;
    }

    return data;
  }

  // Server timestamp
  static serverTimestamp(): FieldValue {
    return serverTimestamp();
  }

  // Increment helper
  static increment(value: number): FieldValue {
    return firestoreIncrement(value);
  }

  // Array union helper
  static arrayUnion(...elements: any[]): FieldValue {
    return arrayUnion(...elements);
  }

  // Array remove helper
  static arrayRemove(...elements: any[]): FieldValue {
    return arrayRemove(...elements);
  }
}

// Export query builders
export { collection, doc, query, where, orderBy, limit, startAfter };

// Export Firestore instance
export { firestore };

