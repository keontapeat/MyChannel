# MyChannel Ads

A self-serve advertising platform with **Google AdSense parity** — both the
**demand side** (advertisers buy CPM/CPC inventory, OpenRTB, VAST video) and the
**supply side** (publishers monetize sites with an embeddable ad tag, earnings,
RPM reporting, and monthly payouts).

> Scope note: this is a complete, working AdSense-equivalent core — accounts,
> ad serving, auctions, fraud filtering, earnings, payouts, and policy controls.
> It is not Google's planet-scale ad exchange, but it implements the same model
> end to end and runs on the existing MyChannel stack (Fastify + Postgres).

## Architecture

```
Advertiser ──> campaigns / line_items / creatives ──┐
                                                     ▼
Publisher site <── mca.js tag ──> /pub/ad ──> second-price auction ──> creative
       │                                │ (CPM + CPC, CTR-predicted eCPM)
       │                                ├──> impression / viewability / click tracking
       │                                ├──> invalid-traffic (IVT) filtering
       ▼                                ▼
  RPM reports <── earnings ledger (68% rev-share) ──> monthly payouts ($100 min)
```

## Feature parity with AdSense

| AdSense feature | MyChannel Ads |
| --- | --- |
| Publisher ID `pub-XXXX…` | `publishers.publisher_code` |
| Site verification (ads.txt) | `POST /pub/sites/:id/verify` (crawls ads.txt) |
| Ad units + ad code snippet | `POST /pub/adunits` → `adsbymychannel` `<ins>` tag |
| `adsbygoogle.js` loader | `GET /mca.js` |
| Display / in-article / in-feed / multiplex | `ad_units.format` |
| Auction (CPM + CPC) | `lib/auction.js` second-price on predicted eCPM |
| CTR prediction | `lib/auction.js` Bayesian-shrinkage `predictCtr` |
| Invalid traffic filtering | `lib/ivt.js` |
| Reports (earnings/CTR/RPM/coverage) | `GET /pub/reports/*` |
| Blocking controls | `PUT /pub/blocking-controls` |
| Policy center | `/pub/policy*` |
| Payments threshold + monthly payout | `/pub/payments*` + `jobs/payouts.js` |
| Revenue share (68%) | `publishers.revshare_bps` |
| ads.txt as authorized seller | `GET /ads.txt` |

## Run locally

```bash
cd services/ads
npm install
export DATABASE_URL=postgres://localhost/mychannel_ads
export ADS_BASE_URL=http://localhost:9093
export ADS_PUBLIC_BASE=http://localhost:9093      # base the tag calls back to
export ADS_TAG_HOST=https://cdn.mychannel.com     # where mca.js is hosted

node src/migrate.js            # demand-side schema (existing)
node src/migrate-adsense.js    # supply-side schema (publishers etc.)
node src/index.js
```

## Publisher quickstart (AdSense flow)

1. **Sign up** — `POST /pub/signup { "email": "me@site.com", "url": "site.com" }`
   → returns your `publisher_code` (`pub-…`) and API key.
2. **Verify your site** — add the `adsTxtLine` to `https://site.com/ads.txt`, then
   `POST /pub/sites/:id/verify`.
3. **Get approved** — `POST /pub/:code/review { "decision": "approve" }` (admin).
4. **Create an ad unit** — `POST /pub/adunits { "name":"Leaderboard","format":"display" }`
   → returns the copy-paste ad code.
5. **Paste the code** on your page (see `public/demo-publisher.html`).
6. **Watch earnings** — `GET /pub/reports/overview`.
7. **Get paid** — set a payment profile (`PUT /pub/payments/profile`); payouts run
   monthly on the 21st once your balance ≥ `$100`.

## Key endpoints

Publisher: `/pub/signup`, `/pub/account`, `/pub/sites`, `/pub/adunits`,
`/pub/ad` (serving), `/pub/click`, `/pub/reports/overview|timeseries|breakdown`,
`/pub/payments*`, `/pub/policy*`, `/pub/blocking-controls`.

Advertiser (existing): `/ads/campaign`, `/ads/creative`, `/ads/fund`,
`/ads/serve`, `/ads/vmap`, `/openrtb2/auction`.

Public: `/mca.js`, `/ads.txt`, `/health`.

## Tests

```bash
node test-auction.mjs   # second-price auction + CTR prediction (no DB)
node test-tag.mjs       # embeddable tag JS compiles & exposes push() API
```

## Demand/supply revenue flow

- **CPM** demand books revenue at impression time; **CPC** demand books on a valid click.
- Each booking writes to `pub_ledger` (running balance) and applies the publisher's
  `revshare_bps` (default 6800 = 68%).
- Invalid clicks are flagged by `lib/ivt.js`, recorded in `fraud_events`, and **not** paid.
- `jobs/payouts.js` issues monthly payouts for publishers over threshold.
