import { useEffect, useState } from 'react'

const BASE = process.env.NEXT_PUBLIC_RIGHTS_BASE || 'http://localhost:9098'

export default function RightsAdmin() {
  const [videoId, setVideoId] = useState('example')
  const [data, setData] = useState<any>(null)
  async function load() {
    const res = await fetch(`${BASE}/rights/video/${videoId}`)
    const j = await res.json(); setData(j)
  }
  useEffect(()=>{ /* noop */ }, [])
  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system' }}>
      <h1>Rights Dashboard</h1>
      <div style={{ display: 'grid', gap: 8, maxWidth: 520 }}>
        <label>Video ID <input value={videoId} onChange={e=>setVideoId(e.target.value)} /></label>
        <button onClick={load}>Load</button>
        {data && (<div>
          <div>License: {data.license_code}</div>
          <div dangerouslySetInnerHTML={{ __html: data.attribution_html }} />
        </div>)}
      </div>
    </main>
  )
}



