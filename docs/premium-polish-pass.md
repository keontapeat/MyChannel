# Premium Polish Pass — Remaining Wave

Consolidated checklist for accessibility, adaptive UI, and haptics not yet audited feature-by-feature.

## ✅ Done this batch

- Compliance sheet: per-action loading, reduce motion on buttons, region TextField, KYC poll + debounce
- Super Thanks: accessibility labels on amount chips + sheet container
- Flicks: spring UI show/hide when reduce motion off
- Match errors: `NSLocalizedString` keys in `MatchError`
- Payout success haptic in `CreatorPayoutService`
- Deep link: `/medals/vs-match?id=` → `DeepLinkRouter.targetVSMatchId`

## 🔲 VoiceOver

- [ ] Audit all money sheets (Wallet deposit, Super Thanks, VS compliance) for grouped traits
- [ ] Announce KYC state changes when poll flips to approved
- [ ] Escrow error alerts: accessibility hint with support link

## 🔲 Dynamic Type

- [ ] Compliance sheet action buttons scale with `@ScaledMetric` min height 44pt
- [ ] Wager amount fields support `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)`

## 🔲 Safe area / Keyboard

- [ ] Compliance region TextField: `.scrollDismissesKeyboard(.interactively)`
- [ ] Super Thanks message field keyboard avoidance verified on SE size class

## 🔲 Focus / iPad

- [ ] `@FocusState` on region TextField for hardware keyboard Return → Save
- [ ] iPad: compliance sheet as `.formSheet` not full screen cover

## 🔲 RTL

- [ ] Mirror action rail in Flicks for RTL layouts (`leading`/`trailing` not hard-coded left)
- [ ] Money amount formatting uses `FormatStyle.Currency` with locale

## 🔲 Dark mode

- [ ] Compliance feedback banners use semantic colors (`.orange`/`.red` → AppTheme error/warning)
- [ ] Super Thanks gradient header tested in dark appearance

## 🔲 Haptics (reference)

| Action | Style |
|--------|-------|
| Tab / chip | `.light` |
| Primary CTA | `.medium` |
| Success payout / compliance clear | `.success` notification |
| Destructive | `.warning` |

## 🔲 Web medals empty state

Already implemented in `web-v2/app/medals/page.tsx` — no iOS action required.

## Related docs

- `.cursorrules` Premium Polish Checklist
- `docs/scroll-60fps.md`
- `docs/analytics-event-naming-money.md`
