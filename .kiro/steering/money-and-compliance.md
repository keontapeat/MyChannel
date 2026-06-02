# Real-Money Features & Compliance

MyChannel handles real money: VS Matches wagers ($1–$100,000), escrow, tips, payouts, and ad revenue. Treat any code touching money, wagers, KYC, payouts, or escrow as **high-risk**. Get it right and be conservative.

## Always-Required Compliance Checks (both iOS and Web)
Before creating or settling any real-money match/wager:
1. **Age verification** — user must be 18+.
2. **KYC** — required for wagers of $500 or more.
3. **Terms acceptance** — user must have accepted current terms.
4. **Region check** — verify the user's region allows real-money play.
5. **Daily limits** — enforce per-user daily wager limits.

Never bypass, stub out, or "temporarily disable" these checks. If a task seems to require skipping a check, stop and confirm with the user.

## Money Handling Rules
- Platform fee is **10%** on VS Matches.
- All wager funds flow through escrow (`MoneyEscrowService` on iOS). Never move money outside escrow.
- Use integer cents or a decimal money type for currency math — never raw floating-point dollars.
- All money mutations must be atomic/transactional (Firestore transactions or batched writes). No partial state.
- Log money events for auditability, but never log full PII, card data, or secrets.
- Payouts and escrow changes must be idempotent — guard against double-processing.

## Wager Divisions (Championship Belt System)
- Lightweight: $1–$100
- Welterweight: $101–$500
- Middleweight: $501–$1K
- Heavyweight: $1K–$5K
- Super Heavyweight: $5K–$10K
- Ultra Heavyweight: $10K+

## Security
- Never hardcode secrets. iOS uses `AppSecrets`; web uses environment variables (`NEXT_PUBLIC_*` only for values safe to expose client-side — never put server secrets in `NEXT_PUBLIC_*`).
- Enforce Firebase Security Rules; never rely on client-side checks alone for money or auth.
- Validate and sanitize all user input on the server side.
- When creating any network-exposed endpoint, confirm auth/authorization is present. Flag it if absent.
