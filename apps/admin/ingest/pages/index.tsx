import { useState } from 'react'

const BASE = process.env.NEXT_PUBLIC_INGEST_BASE || 'http://localhost:9097'

export default function IngestAdmin() {
  const [source, setSource] = useState<'PEXELS'|'PIXABAY'|'ARCHIVE'|'WIKI'>('PEXELS')
  const [query, setQuery] = useState('city')
  const [logs, setLogs] = useState<string>('Ready')
  async function pull() {
    const res = await fetch(`${BASE}/ingest/source/pull`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ source, query, perPage: 5, pages: 1 }) })
    const j = await res.json(); setLogs(JSON.stringify(j, null, 2))
  }
  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system' }}>
      <h1>Ingest Admin</h1>
      <div style={{ display: 'grid', gap: 8, maxWidth: 520 }}>
        <label>Source <select value={source} onChange={e=>setSource(e.target.value as any)}><option>PEXELS</option><option>PIXABAY</option><option>ARCHIVE</option><option>WIKI</option></select></label>
        <label>Query <input value={query} onChange={e=>setQuery(e.target.value)} /></label>
        <button onClick={pull}>Pull</button>
        <pre style={{ background: '#f6f6f6', padding: 12 }}>{logs}</pre>
      </div>
    </main>
  )
}



