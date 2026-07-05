'use client';

// Sign in — premium light-mode login, Firebase AuthService.

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Loader2 } from 'lucide-react';
import { authService } from '@/lib/firebase/auth';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [focusedField, setFocusedField] = useState<string | null>(null);

  const handleEmailLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await authService.signInWithEmail(email, password);
      router.push('/');
    } catch {
      setError('Invalid email or password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    setError(null);
    setLoading(true);
    try {
      await authService.signInWithGoogle();
      router.push('/');
    } catch {
      setError('Google sign-in failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-white via-gray-50 to-red-50/30 px-4 py-12 relative overflow-hidden">
      {/* Subtle background accents */}
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-gradient-to-bl from-red-100/40 to-transparent rounded-full blur-3xl -translate-y-1/2 translate-x-1/4 pointer-events-none" />
      <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-gradient-to-tr from-red-50/50 to-transparent rounded-full blur-3xl translate-y-1/3 -translate-x-1/4 pointer-events-none" />

      <div className="w-full max-w-[420px] relative z-10">
        {/* Card */}
        <div className="bg-white rounded-2xl shadow-[0_4px_48px_rgba(0,0,0,0.08)] border border-gray-100/80 p-8 sm:p-10">
          {/* Logo & branding */}
          <Link href="/" className="flex items-center justify-center gap-2.5 mb-8 group">
            <div className="w-10 h-10 rounded-xl bg-red-600 flex items-center justify-center shadow-md shadow-red-200/50 group-hover:shadow-red-300/60 transition-shadow">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M8 5.14v14l11-7-11-7z" fill="white" />
              </svg>
            </div>
            <span className="text-xl font-bold text-gray-900 tracking-tight">MyChannel</span>
          </Link>

          <h1 className="text-[26px] font-bold text-gray-900 text-center mb-1 tracking-tight">Welcome back</h1>
          <p className="text-[15px] text-gray-500 text-center mb-8">Sign in to your creator account</p>

          {/* Error banner */}
          {error && (
            <div className="mb-5 flex items-start gap-3 rounded-xl bg-red-50 border border-red-100 px-4 py-3">
              <svg className="w-5 h-5 text-red-500 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
              <p className="text-sm text-red-700 leading-snug">{error}</p>
            </div>
          )}

          {/* Google sign-in (primary social — above the fold like YouTube) */}
          <button
            onClick={handleGoogleLogin}
            disabled={loading}
            className="flex w-full items-center justify-center gap-3 rounded-xl border border-gray-200 bg-white py-3.5 text-[15px] font-medium text-gray-700 transition-all hover:bg-gray-50 hover:border-gray-300 hover:shadow-sm active:scale-[0.98] disabled:opacity-60 disabled:pointer-events-none"
          >
            <svg width="18" height="18" viewBox="0 0 24 24">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
            </svg>
            Continue with Google
          </button>

          {/* Divider */}
          <div className="my-6 flex items-center gap-4">
            <span className="h-px flex-1 bg-gradient-to-r from-transparent via-gray-200 to-transparent" />
            <span className="text-xs font-medium text-gray-400 uppercase tracking-wider">or</span>
            <span className="h-px flex-1 bg-gradient-to-r from-transparent via-gray-200 to-transparent" />
          </div>

          {/* Email/Password form */}
          <form onSubmit={handleEmailLogin} className="space-y-4">
            <div className="space-y-3">
              {/* Email field */}
              <div className={`relative rounded-xl border transition-all duration-200 ${focusedField === 'email' ? 'border-red-500 shadow-[0_0_0_3px_rgba(239,68,68,0.08)]' : 'border-gray-200 hover:border-gray-300'}`}>
                <label className={`absolute left-4 transition-all duration-200 pointer-events-none ${focusedField === 'email' || email ? 'top-2 text-[11px] font-medium text-red-500' : 'top-1/2 -translate-y-1/2 text-[15px] text-gray-400'}`}>
                  Email address
                </label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onFocus={() => setFocusedField('email')}
                  onBlur={() => setFocusedField(null)}
                  className="w-full rounded-xl bg-transparent pt-6 pb-2.5 px-4 text-[15px] text-gray-900 outline-none"
                  aria-label="Email address"
                />
              </div>

              {/* Password field */}
              <div className={`relative rounded-xl border transition-all duration-200 ${focusedField === 'password' ? 'border-red-500 shadow-[0_0_0_3px_rgba(239,68,68,0.08)]' : 'border-gray-200 hover:border-gray-300'}`}>
                <label className={`absolute left-4 transition-all duration-200 pointer-events-none ${focusedField === 'password' || password ? 'top-2 text-[11px] font-medium text-red-500' : 'top-1/2 -translate-y-1/2 text-[15px] text-gray-400'}`}>
                  Password
                </label>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onFocus={() => setFocusedField('password')}
                  onBlur={() => setFocusedField(null)}
                  className="w-full rounded-xl bg-transparent pt-6 pb-2.5 px-4 text-[15px] text-gray-900 outline-none"
                  aria-label="Password"
                />
              </div>
            </div>

            {/* Forgot password */}
            <div className="flex justify-end">
              <Link href="/forgot-password" className="text-[13px] font-medium text-red-600 hover:text-red-700 transition-colors">
                Forgot password?
              </Link>
            </div>

            {/* Sign in button */}
            <button
              type="submit"
              disabled={loading}
              className="relative flex w-full items-center justify-center gap-2 rounded-xl bg-red-600 py-3.5 text-[15px] font-semibold text-white transition-all hover:bg-red-700 hover:shadow-lg hover:shadow-red-200/50 active:scale-[0.98] disabled:opacity-60 disabled:pointer-events-none overflow-hidden"
            >
              <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent translate-x-[-100%] hover:translate-x-[100%] transition-transform duration-700" />
              {loading ? <Loader2 size={18} className="animate-spin" /> : 'Sign in'}
            </button>
          </form>
        </div>

        {/* Footer link */}
        <p className="mt-6 text-center text-[15px] text-gray-500">
          New to MyChannel?{' '}
          <Link href="/signup" className="font-semibold text-red-600 hover:text-red-700 transition-colors">
            Create account
          </Link>
        </p>

        {/* Terms */}
        <p className="mt-4 text-center text-[12px] text-gray-400 leading-relaxed max-w-[320px] mx-auto">
          By continuing, you agree to our{' '}
          <Link href="/terms" className="underline hover:text-gray-600 transition-colors">Terms of Service</Link>{' '}
          and{' '}
          <Link href="/privacy" className="underline hover:text-gray-600 transition-colors">Privacy Policy</Link>.
        </p>
      </div>
    </div>
  );
}
