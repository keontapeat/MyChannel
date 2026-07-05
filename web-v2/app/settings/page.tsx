'use client';

// Settings — account, playback, notifications, privacy (YouTube-parity shell).

import MainLayout from '@/components/layout/MainLayout';
import { useState } from 'react';
import { Settings as SettingsIcon, User, Bell, Play, Shield, Globe } from 'lucide-react';

type Section = 'account' | 'playback' | 'notifications' | 'privacy' | 'language' | 'family' | 'geo';

const SECTIONS: { id: Section; label: string; icon: typeof User }[] = [
  { id: 'account', label: 'Account', icon: User },
  { id: 'playback', label: 'Playback', icon: Play },
  { id: 'notifications', label: 'Notifications', icon: Bell },
  { id: 'privacy', label: 'Privacy', icon: Shield },
  { id: 'language', label: 'Language & region', icon: Globe },
  { id: 'family', label: 'Family & safety', icon: Shield },
  { id: 'geo', label: 'Content restrictions', icon: Globe },
];

function Toggle({ label, defaultOn = false }: { label: string; defaultOn?: boolean }) {
  const [on, setOn] = useState(defaultOn);
  return (
    <div className="flex items-center justify-between py-3 border-b border-[rgb(var(--color-border))] last:border-0">
      <span className="text-sm text-[rgb(var(--color-text-primary))]">{label}</span>
      <button
        onClick={() => setOn(!on)}
        className={`relative h-6 w-11 rounded-full transition-colors ${on ? 'bg-[rgb(var(--color-primary))]' : 'bg-gray-300'}`}
        aria-pressed={on}
        aria-label={label}
      >
        <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${on ? 'translate-x-5' : 'translate-x-0.5'}`} />
      </button>
    </div>
  );
}

export default function SettingsPage() {
  const [active, setActive] = useState<Section>('account');
  const [restrictedMode, setRestrictedMode] = useState(false);
  const [parentalPin, setParentalPin] = useState('');
  const [parentalEnabled, setParentalEnabled] = useState(false);
  const [blockedRegions, setBlockedRegions] = useState<string[]>([]);
  const [geoRespect, setGeoRespect] = useState(true);

  return (
    <MainLayout>
      <div className="max-w-[1100px] mx-auto px-4 sm:px-6 py-6">
        <div className="flex items-center gap-3 mb-6">
          <SettingsIcon size={24} className="text-[rgb(var(--color-text-primary))]" />
          <h1 className="text-2xl font-bold text-[rgb(var(--color-text-primary))]">Settings</h1>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-[220px_1fr] gap-6">
          {/* Section nav */}
          <nav className="space-y-1">
            {SECTIONS.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActive(id)}
                className={`flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm transition-colors ${
                  active === id
                    ? 'bg-[rgb(var(--color-surface))] font-medium text-[rgb(var(--color-text-primary))]'
                    : 'text-[rgb(var(--color-text-secondary))] hover:bg-[rgb(var(--color-surface-hover))]'
                }`}
              >
                <Icon size={18} />
                {label}
              </button>
            ))}
          </nav>

          {/* Panel */}
          <div className="rounded-xl border border-[rgb(var(--color-border))] p-5">
            {active === 'account' && (
              <div>
                <h2 className="mb-4 text-lg font-bold text-[rgb(var(--color-text-primary))]">Account</h2>
                <p className="text-sm text-[rgb(var(--color-text-secondary))]">
                  Manage your channel name, email, and password from your account profile.
                </p>
              </div>
            )}
            {active === 'playback' && (
              <div>
                <h2 className="mb-2 text-lg font-bold text-[rgb(var(--color-text-primary))]">Playback</h2>
                <Toggle label="Autoplay next video" defaultOn />
                <Toggle label="Play videos at HD by default" />
                <Toggle label="Reduced motion" />
              </div>
            )}
            {active === 'notifications' && (
              <div>
                <h2 className="mb-2 text-lg font-bold text-[rgb(var(--color-text-primary))]">Notifications</h2>
                <Toggle label="New uploads from subscriptions" defaultOn />
                <Toggle label="Replies to my comments" defaultOn />
                <Toggle label="Recommended videos" />
              </div>
            )}
            {active === 'privacy' && (
              <div>
                <h2 className="mb-2 text-lg font-bold text-[rgb(var(--color-text-primary))]">Privacy</h2>
                <Toggle label="Keep my watch history private" />
                <Toggle label="Keep my liked videos private" defaultOn />
                <Toggle label="Keep my subscriptions private" />
              </div>
            )}
            {active === 'language' && (
              <div>
                <h2 className="mb-4 text-lg font-bold text-[rgb(var(--color-text-primary))]">Language &amp; region</h2>
                <label className="block text-sm text-[rgb(var(--color-text-secondary))] mb-2">Language</label>
                <select className="w-full rounded-lg border border-[rgb(var(--color-border))] bg-transparent px-3 py-2 text-sm text-[rgb(var(--color-text-primary))]">
                  <option>English (US)</option>
                  <option>Español</option>
                  <option>Français</option>
                  <option>Português</option>
                </select>
              </div>
            )}
            {active === 'family' && (
              <div>
                <h2 className="mb-4 text-lg font-bold text-[rgb(var(--color-text-primary))]">Family &amp; Safety</h2>
                <div className="space-y-4">
                  <div className="flex items-center justify-between py-3 border-b border-[rgb(var(--color-border))]">
                    <div>
                      <p className="text-sm font-medium text-[rgb(var(--color-text-primary))]">Restricted Mode</p>
                      <p className="text-xs text-[rgb(var(--color-text-secondary))]">Hide potentially mature content from search and recommendations</p>
                    </div>
                    <button
                      onClick={() => setRestrictedMode(!restrictedMode)}
                      className={`relative h-6 w-11 rounded-full transition-colors ${restrictedMode ? 'bg-[rgb(var(--color-primary))]' : 'bg-gray-300'}`}
                      aria-pressed={restrictedMode}
                    >
                      <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${restrictedMode ? 'translate-x-5' : 'translate-x-0.5'}`} />
                    </button>
                  </div>
                  <div className="py-3 border-b border-[rgb(var(--color-border))]">
                    <div className="flex items-center justify-between mb-2">
                      <div>
                        <p className="text-sm font-medium text-[rgb(var(--color-text-primary))]">Parental controls</p>
                        <p className="text-xs text-[rgb(var(--color-text-secondary))]">Require a PIN to disable restricted mode or view age-restricted content</p>
                      </div>
                      <button
                        onClick={() => setParentalEnabled(!parentalEnabled)}
                        className={`relative h-6 w-11 rounded-full transition-colors ${parentalEnabled ? 'bg-[rgb(var(--color-primary))]' : 'bg-gray-300'}`}
                        aria-pressed={parentalEnabled}
                      >
                        <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${parentalEnabled ? 'translate-x-5' : 'translate-x-0.5'}`} />
                      </button>
                    </div>
                    {parentalEnabled && (
                      <input
                        type="password"
                        value={parentalPin}
                        onChange={(e) => setParentalPin(e.target.value.replace(/\D/g, '').slice(0, 6))}
                        placeholder="Set 4–6 digit PIN"
                        className="w-40 px-3 py-2 text-sm bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-lg text-[rgb(var(--color-text-primary))] outline-none focus:border-[rgb(var(--color-primary))]"
                        maxLength={6}
                        inputMode="numeric"
                        aria-label="Parental control PIN"
                      />
                    )}
                  </div>
                  <div className="py-3">
                    <p className="text-sm font-medium text-[rgb(var(--color-text-primary))] mb-1">Age-restricted content</p>
                    <p className="text-xs text-[rgb(var(--color-text-secondary))]">
                      Videos marked 18+ require sign-in to view. If parental controls are enabled, the PIN is also required.
                    </p>
                  </div>
                </div>
              </div>
            )}
            {active === 'geo' && (
              <div>
                <h2 className="mb-4 text-lg font-bold text-[rgb(var(--color-text-primary))]">Content restrictions</h2>
                <div className="space-y-4">
                  <div className="flex items-center justify-between py-3 border-b border-[rgb(var(--color-border))]">
                    <div>
                      <p className="text-sm font-medium text-[rgb(var(--color-text-primary))]">Respect geographic restrictions</p>
                      <p className="text-xs text-[rgb(var(--color-text-secondary))]">Hide content that isn&apos;t available in your region</p>
                    </div>
                    <button
                      onClick={() => setGeoRespect(!geoRespect)}
                      className={`relative h-6 w-11 rounded-full transition-colors ${geoRespect ? 'bg-[rgb(var(--color-primary))]' : 'bg-gray-300'}`}
                      aria-pressed={geoRespect}
                    >
                      <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${geoRespect ? 'translate-x-5' : 'translate-x-0.5'}`} />
                    </button>
                  </div>
                  <div className="py-3">
                    <p className="text-sm font-medium text-[rgb(var(--color-text-primary))] mb-2">Blocked regions</p>
                    <p className="text-xs text-[rgb(var(--color-text-secondary))] mb-3">
                      Content blocked in these regions will be hidden from your feed
                    </p>
                    <div className="flex flex-wrap gap-2 mb-3">
                      {blockedRegions.map((region) => (
                        <span key={region} className="flex items-center gap-1 px-2 py-1 bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] rounded-full text-xs text-[rgb(var(--color-text-primary))]">
                          {region}
                          <button
                            onClick={() => setBlockedRegions((r) => r.filter((x) => x !== region))}
                            className="hover:text-red-500 ml-0.5"
                            aria-label={`Remove ${region}`}
                          >
                            ×
                          </button>
                        </span>
                      ))}
                      {blockedRegions.length === 0 && (
                        <p className="text-xs text-[rgb(var(--color-text-tertiary))]">No regions blocked</p>
                      )}
                    </div>
                    <select
                      onChange={(e) => {
                        const val = e.target.value;
                        if (val && !blockedRegions.includes(val)) {
                          setBlockedRegions([...blockedRegions, val]);
                        }
                        e.target.value = '';
                      }}
                      className="rounded-lg border border-[rgb(var(--color-border))] bg-transparent px-3 py-2 text-sm text-[rgb(var(--color-text-primary))]"
                      aria-label="Add blocked region"
                    >
                      <option value="">+ Add region…</option>
                      {['US', 'UK', 'CA', 'AU', 'EU', 'CN', 'RU', 'IN', 'JP', 'KR', 'BR', 'MX'].map((r) => (
                        <option key={r} value={r}>{r}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
