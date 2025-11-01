import { useState } from 'react'
import { api, getEmail } from '../../lib/api'
import { useRouter } from 'next/router'
import Nav from '../../components/Nav'

export default function NewCampaign() {
  const [name, setName] = useState('Launch')
  const [topic, setTopic] = useState('gaming')
  const [placement, setPlacement] = useState('preroll')
  const [bid, setBid] = useState(500)
  const [creativeUrl, setCreativeUrl] = useState('https://storage.googleapis.com/mock/creative.mp4')
  const [clickUrl, setClickUrl] = useState('https://brand.example')
  const router = useRouter()

  async function submit() {
    const email = getEmail(); if (!email) { alert('login first'); return }
    const body = {
      email,
      advertiserName: 'Brand',
      name,
      status: 'active',
      topics: [topic],
      line_items: [{ placement, bid_cpm_cents: Number(bid), targeting_json: { topics: [topic] } }]
    }
    const created = await api<{ id:number; line_item_ids:number[] }>(`/ads/campaign`, 'POST', body)
    if (created.line_item_ids?.length) {
      await api(`/ads/creative`, 'POST', { line_item_id: created.line_item_ids[0], type: 'video', uri: creativeUrl, click_url: clickUrl, duration_sec: 15 })
    }
    router.push('/campaigns')
  }

  return (
    <main style={{ padding: 0, fontFamily: 'system-ui, -apple-system' }}>
      <Nav />
      <div style={{ padding: 24 }}>
      <h1>New Campaign</h1>
      <div style={{ display: 'grid', gap: 12, maxWidth: 520, marginTop: 12 }}>
        <label>Name <input value={name} onChange={e=>setName(e.target.value)} /></label>
        <label>Topic <input value={topic} onChange={e=>setTopic(e.target.value)} /></label>
        <label>Placement <select value={placement} onChange={e=>setPlacement(e.target.value)}><option value="preroll">preroll</option><option value="midroll">midroll</option><option value="postroll">postroll</option></select></label>
        <label>Bid CPM (cents) <input type="number" value={bid} onChange={e=>setBid(Number(e.target.value))} /></label>
        <label>Creative URL <input value={creativeUrl} onChange={e=>setCreativeUrl(e.target.value)} /></label>
        <label>Click URL <input value={clickUrl} onChange={e=>setClickUrl(e.target.value)} /></label>
      </div>
      <button onClick={submit} style={{ marginTop: 16, padding: '10px 14px' }}>Create</button>
      </div>
    </main>
  )
}


