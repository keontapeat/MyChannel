// Firebase Authentication Service for MyChannel Web

import {
  User as FirebaseUser,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  sendPasswordResetEmail,
  updateProfile,
  GoogleAuthProvider,
  signInWithPopup,
  setPersistence,
  browserLocalPersistence,
} from 'firebase/auth';
import { auth } from './config';
import type { User } from '@/types';

export class AuthService {
  private static instance: AuthService;

  private constructor() {
    // Set persistence to local (keeps user logged in)
    if (typeof window !== 'undefined') {
      setPersistence(auth, browserLocalPersistence).catch(console.error);
    }
  }

  static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  // Sign up with email and password
  async signUpWithEmail(
    email: string,
    password: string,
    displayName: string
  ): Promise<FirebaseUser> {
    try {
      const userCredential = await createUserWithEmailAndPassword(
        auth,
        email,
        password
      );

      // Update profile with display name
      await updateProfile(userCredential.user, {
        displayName,
      });

      console.log('✅ User signed up:', userCredential.user.uid);
      return userCredential.user;
    } catch (error) {
      console.error('🚨 Sign up error:', error);
      throw error;
    }
  }

  // Sign in with email and password
  async signInWithEmail(email: string, password: string): Promise<FirebaseUser> {
    try {
      const userCredential = await signInWithEmailAndPassword(
        auth,
        email,
        password
      );

      console.log('✅ User signed in:', userCredential.user.uid);
      return userCredential.user;
    } catch (error) {
      console.error('🚨 Sign in error:', error);
      throw error;
    }
  }

  // Sign in with Google
  async signInWithGoogle(): Promise<FirebaseUser> {
    try {
      const provider = new GoogleAuthProvider();
      const userCredential = await signInWithPopup(auth, provider);

      console.log('✅ User signed in with Google:', userCredential.user.uid);
      return userCredential.user;
    } catch (error) {
      console.error('🚨 Google sign in error:', error);
      throw error;
    }
  }

  // Sign out
  async signOut(): Promise<void> {
    try {
      await firebaseSignOut(auth);
      console.log('✅ User signed out');
    } catch (error) {
      console.error('🚨 Sign out error:', error);
      throw error;
    }
  }

  // Send password reset email
  async sendPasswordReset(email: string): Promise<void> {
    try {
      await sendPasswordResetEmail(auth, email);
      console.log('✅ Password reset email sent to:', email);
    } catch (error) {
      console.error('🚨 Password reset error:', error);
      throw error;
    }
  }

  // Get current user
  getCurrentUser(): FirebaseUser | null {
    return auth.currentUser;
  }

  // Get current user ID
  getCurrentUserId(): string | null {
    return auth.currentUser?.uid || null;
  }

  // Check if user is authenticated
  isAuthenticated(): boolean {
    return auth.currentUser !== null;
  }

  // Check if user is admin.
  //
  // Admin status comes from a Firebase custom claim (`admin: true`) set
  // server-side (Cloud Function / Admin SDK) — it cannot be forged by the
  // client. NOTE: this is only for UI gating. All privileged reads/writes must
  // still be enforced by Firestore/Storage Security Rules and server code;
  // never trust this client-side check alone for access control.
  async isAdmin(): Promise<boolean> {
    const user = auth.currentUser;
    if (!user) return false;

    try {
      const token = await user.getIdTokenResult();
      return token.claims.admin === true;
    } catch (error) {
      console.error('🚨 isAdmin claim check error:', error);
      return false;
    }
  }

  // Listen to auth state changes
  onAuthStateChange(callback: (user: FirebaseUser | null) => void): () => void {
    return onAuthStateChanged(auth, callback);
  }

  // Get ID token for API calls
  async getIdToken(): Promise<string | null> {
    const user = auth.currentUser;
    if (!user) return null;

    try {
      return await user.getIdToken();
    } catch (error) {
      console.error('🚨 Get ID token error:', error);
      return null;
    }
  }

  // Refresh ID token
  async refreshIdToken(): Promise<string | null> {
    const user = auth.currentUser;
    if (!user) return null;

    try {
      return await user.getIdToken(true); // Force refresh
    } catch (error) {
      console.error('🚨 Refresh ID token error:', error);
      return null;
    }
  }
}

// Export singleton instance
export const authService = AuthService.getInstance();

// Export auth state hook utility
export const useAuthState = (
  callback: (user: FirebaseUser | null) => void
): (() => void) => {
  return authService.onAuthStateChange(callback);
};

