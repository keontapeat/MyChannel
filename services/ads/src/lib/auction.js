/**
 * MyChannel Ads — Display/CPC auction engine (AdSense-parity)
 *
 * AdSense runs a second-price auction on *expected revenue per impression* (eCPM),
 * blending CPM and CPC demand. For CPC demand, eCPM = bidCpc * predictedCtr * 1000.
 * The winner is charged the minimum needed to beat the runner-up (second price).
 */

// Smoothed historical CTR per (line item, ad unit format/size). Falls back to a
// global prior so brand-new line items can still compete (cold start).
const GLOBAL_PRIOR_CTR = 0.004 // 0.4% — typical display baseline
const PRIOR_WEIGHT = 200       // pseudo-impressions of prior

export function predictCtr({ clicks = 0, impressions = 0, base = GLOBAL_PRIOR_CTR } = {}) {
  // Bayesian shrinkage toward the prior, so low-volume items aren't over/under-rated.
  const ctr = (clicks + base * PRIOR_WEIGHT) / (impressions + PRIOR_WEIGHT)
  return Math.max(0.0001, Math.min(0.25, ctr))
}

// eCPM in cents for a candidate line item
export function ecpmCents(li, predictedCtr) {
  if (li.pricing_model === 'cpc') {
    return (Number(li.bid_cpc_cents) || 0) * predictedCtr * 1000
  }
  return Number(li.bid_cpm_cents) || 0
}

/**
 * Run the auction.
 * @param {Array} candidates - line items joined with creative + ctr stats
 * @param {number} floorCents - publisher/marketplace floor eCPM in cents
 * @returns {object|null} { winner, clearingEcpmCents, clearingPriceCents, predictedCtr, diagnostics }
 */
export function runDisplayAuction(candidates, floorCents = 0) {
  const scored = candidates.map(li => {
    const predictedCtr = predictCtr({
      clicks: li.hist_clicks || 0,
      impressions: li.hist_impressions || 0,
    })
    return { li, predictedCtr, ecpm: ecpmCents(li, predictedCtr) }
  }).filter(s => s.ecpm >= floorCents)

  if (!scored.length) return null

  scored.sort((a, b) => b.ecpm - a.ecpm)
  const top = scored[0]
  const second = scored[1]

  // Second-price clearing eCPM. With a real runner-up, the winner pays just
  // enough to beat it (runnerUp + 1). With no runner-up, the winner pays the
  // reserve/floor exactly. Always capped between floor and the winner's bid.
  const clearingEcpmCents = second
    ? Math.max(floorCents, Math.min(top.ecpm, second.ecpm + 1))
    : floorCents

  // Convert clearing eCPM back into the price the advertiser actually pays.
  let clearingPriceCents
  if (top.li.pricing_model === 'cpc') {
    // charge per click = clearingEcpm / (ctr * 1000), capped at advertiser's max bid
    const perClick = clearingEcpmCents / (top.predictedCtr * 1000)
    clearingPriceCents = Math.min(Number(top.li.bid_cpc_cents) || 0, Math.ceil(perClick))
  } else {
    clearingPriceCents = clearingEcpmCents // charged per 1000 impressions
  }

  return {
    winner: top.li,
    predictedCtr: top.predictedCtr,
    clearingEcpmCents,
    clearingPriceCents,
    diagnostics: {
      eligibleCount: scored.length,
      floorEcpmCents: floorCents,
      topEcpmCents: Math.round(top.ecpm),
      secondEcpmCents: second ? Math.round(second.ecpm) : null,
      candidates: scored.slice(0, 5).map(s => ({
        lineItemId: s.li.id,
        model: s.li.pricing_model,
        predictedCtr: Number(s.predictedCtr.toFixed(4)),
        ecpmCents: Math.round(s.ecpm),
      })),
    },
  }
}
