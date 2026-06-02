import { runDisplayAuction, predictCtr, ecpmCents } from '../src/lib/auction.js'
import assert from 'assert'

let pass = 0
function ok(name, cond) { assert.ok(cond, name); console.log('  ✓ ' + name); pass++ }

console.log('CTR prediction (Bayesian shrinkage):')
const coldCtr = predictCtr({ clicks: 0, impressions: 0 })
ok('cold-start CTR equals prior (~0.004)', Math.abs(coldCtr - 0.004) < 1e-9)
const hotCtr = predictCtr({ clicks: 50, impressions: 1000 })
ok('high-CTR item shrinks toward observed (>prior, <raw 0.05)', hotCtr > 0.004 && hotCtr < 0.05)

console.log('eCPM conversion:')
ok('CPM line item eCPM = bid', ecpmCents({ pricing_model: 'cpm', bid_cpm_cents: 250 }, 0.01) === 250)
ok('CPC eCPM = cpc*ctr*1000', ecpmCents({ pricing_model: 'cpc', bid_cpc_cents: 40 }, 0.01) === 400)

console.log('Second-price auction:')
const candidates = [
  { id: 1, pricing_model: 'cpm', bid_cpm_cents: 300, hist_clicks: 0, hist_impressions: 0 },
  { id: 2, pricing_model: 'cpm', bid_cpm_cents: 200, hist_clicks: 0, hist_impressions: 0 },
  { id: 3, pricing_model: 'cpc', bid_cpc_cents: 100, hist_clicks: 40, hist_impressions: 1000 }, // ~3.6% ctr -> eCPM ~360
]
const r = runDisplayAuction(candidates, 50)
ok('a winner is chosen', !!r.winner)
ok('CPC item with strong CTR beats flat CPMs', r.winner.id === 3)
ok('clearing eCPM is second-price (just above runner-up 300)', r.clearingEcpmCents === 301)
ok('CPC clearing price within advertiser max bid', r.clearingPriceCents <= 100)
ok('diagnostics expose candidates', r.diagnostics.eligibleCount === 3)

console.log('Floor enforcement:')
const r2 = runDisplayAuction([{ id: 9, pricing_model: 'cpm', bid_cpm_cents: 40 }], 50)
ok('below-floor demand yields no fill', r2 === null)

console.log('Single eligible bidder clears at floor:')
const r3 = runDisplayAuction([{ id: 7, pricing_model: 'cpm', bid_cpm_cents: 500 }], 120)
ok('lone bidder clears at floor', r3.clearingEcpmCents === 120)

console.log('\\nALL AUCTION TESTS PASSED (' + pass + ')')
