import { useEffect, useState } from 'react'
import { ADS_BASE, api } from '../../../apps/ads-portal/lib/api'

type Creative = { id:number; line_item_id:number; uri:string; review_status:string; policy_labels?: string[] }

export default function AdminAds() {
  const [items, setItems] = useState<Creative[]>([])
  async function load() {
    const r = await api<{ creatives: Creative[] }>(`/ads/review/pending`, 'GET')
    setItems(r.creatives)
  }
  useEffect(() => { load() }, [])
  async function act(id: number, decision: 'approve'|'reject') {
    await api(`/ads/review/${id}`, 'POST', { decision })
    await load()
  }
  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system' }}>
      <h1>Ads Admin • Creative Approvals</h1>
      <ul>
        {items.map(c => (
          <li key={c.id} style={{ margin: '12px 0' }}>
            <div><b>#{c.id}</b> • {c.uri}</div>
            <div style={{ fontSize: 12, color: '#666' }}>Status: {c.review_status} {c.policy_labels?.length ? `• ${c.policy_labels.join(', ')}` : ''}</div>
            <div style={{ marginTop: 6 }}>
              <button onClick={()=>act(c.id,'approve')} style={{ marginRight: 8 }}>Approve</button>
              <button onClick={()=>act(c.id,'reject')}>Reject</button>
            </div>
          </li>
        ))}
      </ul>
    </main>
  )
}



