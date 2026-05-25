# MyChannel Ads Service

## Run locally
- Export env: `DATABASE_URL=postgres://...`, `PAY_API_BASE_URL=http://localhost:8888`, `ADS_BASE_URL=http://localhost:9093`
- Migrate: `node src/migrate.js`
- Start: `node src/index.js`

## Seed
- Insert a serving key: `insert into serving_keys(app,placement,key) values('ios','preroll','test_key');`
- Create advertiser/campaign via `POST /ads/campaign` with a line item and add a creative via `POST /ads/creative`.

## Serve API
- `POST /ads/serve` body:
```json
{ "key":"test_key", "placement":"preroll", "locale":"en-US", "device":"ios", "videoContext": { "videoId":"v1", "tags":["gaming"], "topic":"gaming" } }
```
- Response contains creative and tracking URLs. Fire quartiles at 0/25/50/75/100.

## Funding (Stripe test mode)
- `POST /ads/fund { email, amount_cents }` credits virtual balance (Stripe integration can be enabled with STRIPE_SECRET).
- `GET /ads/balance?email=...` returns current balance.

## Settlement
- Nightly job `runNightlySettlement()` aggregates revenue and posts to Pay API `/pay/settlement`.

## Postman
- See `../tests/e2e-ads/MyChannel-Ads.postman_collection.json` (stub) for endpoints.

## Perf (k6)
- Example script in `tests/e2e-ads/k6-serve.js` to hit `/ads/serve` at load.

