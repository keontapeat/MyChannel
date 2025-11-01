import { useEffect, useState } from 'react'
import Link from 'next/link'
import { api, getEmail } from '../../lib/api'
import Nav from '../../components/Nav'

type Creative = { id: number; uri: string; review_status: string }
type LineItem = { id: number; placement: string; bid_cpm_cents: number; creatives: Creative[] }
type Campaign = { id: number; name: string; status: string; line_items: LineItem[] }

export default function Campaigns() {
  const [items, setItems] = useState<Campaign[]>([])
  const [email, setE] = useState('')
  useEffect(() => {
    const em = getEmail(); setE(em)
    if (!em) return
    api<{ campaigns: Campaign[] }>(`/ads/campaigns`, 'GET', { email: em }).then(r => setItems(r.campaigns)).catch(()=>{})
  }, [])
  return (
    <main style={{ padding: 0, fontFamily: 'system-ui, -apple-system' }}>
      <Nav />
      <div style={{ padding: 24 }}>
      <h1>Campaigns</h1>
      <div style={{ marginBottom: 16 }}>
        <Link href="/campaigns/new">New Campaign</Link>
      </div>
      {!email && <p>Please <Link href="/login">login</Link>.</p>}
      <ul>
        {items.map(c => (
          <li key={c.id} style={{ margin: '12px 0' }}>
            <div><b>{c.name}</b> • {c.status}</div>
            <div style={{ fontSize: 12, color: '#666' }}>{c.line_items.length} line items</div>
            <div style={{ marginTop: 4 }}>
              <Link href={`/campaigns/${c.id}`}>View metrics</Link>
            </div>
          </li>
        ))}
      </ul>
      </div>
    </main>
  )
}


