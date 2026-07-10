# App Transport Security Exceptions Review

**File:** `MyChannel/Info.plist` (NSAppTransportSecurity)

## Current settings (2026-07-09)

| Key | Value | Risk |
|-----|-------|------|
| `NSAllowsArbitraryLoads` | `true` | **High** — permits cleartext globally |
| `NSAllowsArbitraryLoadsForMedia` | `true` | Medium — HLS/CDN streams |
| `NSAllowsArbitraryLoadsInWebContent` | `true` | Medium — WKWebView embeds |
| `NSExceptionDomains` | Per-domain overrides | Review each host |

## Recommendation

1. Set `NSAllowsArbitraryLoads` → `false` for Release builds (keep media/web exceptions only).
2. Enumerate every `NSExceptionDomains` entry; remove hosts no longer used.
3. Pin money API hosts (`mychannel.live`, `*.cloudfunctions.net`) to TLS 1.2+ with forward secrecy.
4. Pair with `AppConfig.Security.enableSSLPinning` for production API base URLs.

## Money paths

Escrow CF, Stripe.js, and Firebase Auth **must not** rely on arbitrary loads. Native clients use HTTPS only.

## Tracking

- [ ] Inventory all `NSExceptionDomains` keys
- [ ] Staging exception for dev API (DEBUG only)
- [ ] Release plist strips arbitrary loads
