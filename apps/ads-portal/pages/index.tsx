import { useEffect, useState } from 'react'

export default function Home() {
  const [health, setHealth] = useState<string>('...')
  useEffect(() => {
    const base = process.env.NEXT_PUBLIC_ADS_BASE_URL || 'http://localhost:9093'
    fetch(base + '/health').then(r=>r.json()).then(j=>setHealth(j.status)).catch(()=>setHealth('error'))
  }, [])

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial' }}>
      <h1>MyChannel Ads Portal</h1>
      <p>Status: {health}</p>
      <section style={{ marginTop: 20 }}>
        <h2>Quick Actions</h2>
        <ul>
          <li>Create Campaign (coming soon)</li>
          <li>Upload Creative (coming soon)</li>
          <li>Billing (coming soon)</li>
        </ul>
      </section>
    </main>
  )
}



