'use client';

// Global Auth Context — single Firebase Auth subscription for the entire app.
//
// Why this exists: individual components (TopNav, etc.) used to call
// `authService.onAuthStateChange()` themselves. Every time a page's component
// tree remounts (navigating between different route components unmounts the
// previous tree, including TopNav), that subscription is torn down and a new
// one is created — briefly resetting to "logged out" until Firebase's cached
// session resolves again. Subscribing once here, at the root layout (which
// never unmounts during client-side navigation), eliminates that flicker and
// guarantees consistent auth state across every page.

import { createContext, useContext, useEffect, useState, useMemo } from 'react';
import type { User as FirebaseUser } from 'firebase/auth';
import { authService } from '@/lib/firebase/auth';

interface AuthContextValue {
  user: FirebaseUser | null;
  isAuthenticated: boolean;
  /** True once Firebase has reported the real (possibly null) auth state at least once. */
  authResolved: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  isAuthenticated: false,
  authResolved: false,
  signOut: async () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [authResolved, setAuthResolved] = useState(false);

  useEffect(() => {
    // Subscribed exactly once for the lifetime of the app (root layout
    // never remounts during client-side route changes).
    const unsubscribe = authService.onAuthStateChange((u) => {
      setUser(u);
      setAuthResolved(true);
    });
    return unsubscribe;
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    user,
    isAuthenticated: authResolved && !!user,
    authResolved,
    signOut: () => authService.signOut(),
  }), [user, authResolved]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  return useContext(AuthContext);
}
