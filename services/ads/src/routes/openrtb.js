import { query } from '../lib/db.js'

export default async function registerOpenRTB(app) {
  // OpenRTB 2.5 minimal bidder endpoint (mock/stub)
  app.post('/openrtb2/auction', async (req, reply) => {
    const bidreq = req.body || {}
    // TODO: validate with schema; apply brand-safety tiers and floors
    const imp = (bidreq.imp || [])[0]
    if (!imp) return reply.code(204).send()
    const price = 0.5 // USD CPM mock
    const adm = '<VAST version="3.0"></VAST>' // TODO: inject real VAST from creative
    const bid = {
      id: 'bid-1',
      impid: imp.id || '1',
      price,
      adm,
      crid: 'creative-1',
      adid: 'ad-1',
    }
    const seatbid = [{ seat: 'direct', bid: [bid] }]
    const resp = { id: bidreq.id || 'req', seatbid, cur: 'USD' }
    return reply.send(resp)
  })
}




