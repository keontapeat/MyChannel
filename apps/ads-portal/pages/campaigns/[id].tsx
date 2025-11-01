import { useRouter } from 'next/router'
import { useEffect, useState } from 'react'
import { api } from '../../lib/api'
import Nav from '../../components/Nav'

type Metrics = {
  impressions: number
  clicks: number
  ctr: number
  spend_cents: number
  ecpm_cents: number
  timeseries: { t: string; imps: number; clicks: number; spend_cents: number }[]
}

export default function CampaignDetail() {
  const router = useRouter()
  const { id } = router.query
  const [data, setData] = useState<Metrics | null>(null)
  useEffect(() => {
    if (!id) return
    api<Metrics>(`/ads/campaign/${id}/metrics`, 'GET').then(setData).catch(()=>{})
  }, [id])
  return (
    <main style={{ padding: 0, fontFamily: 'system-ui, -apple-system' }}>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Campaign #{id}</h1>
        {!data && <div>Loading...</div>}
        {data && (
          <div style={{ display: 'grid', gap: 16 }}>
            <div style={{ display: 'flex', gap: 24 }}>
              <Metric label="Impressions" value={data.impressions.toLocaleString()} />
              <Metric label="Clicks" value={data.clicks.toLocaleString()} />
              <Metric label="CTR" value={(data.ctr * 100).toFixed(2) + '%'} />
              <Metric label="Spend" value={`$${(data.spend_cents/100).toFixed(2)}`} />
              <Metric label="eCPM" value={`$${(data.ecpm_cents/100).toFixed(2)}`} />
            </div>
            <div>
              <h3 style={{ margin: '12px 0' }}>Daily performance</h3>
              <MiniChart series={data.timeseries} />
            </div>
          </div>
        )}
      </div>
    </main>
  )
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{value}</div>
    </div>
  )
}

function MiniChart({ series }: { series: { t: string; imps: number; clicks: number; spend_cents: number }[] }) {
  // very simple column chart in pure DOM for now
  const max = Math.max(1, ...series.map(s => s.imps))
  return (
    <div style={{ display: 'flex', alignItems: 'end', gap: 6, height: 120, borderBottom: '1px solid #eee', paddingBottom: 8 }}>
      {series.map(s => (
        <div key={s.t} title={`${s.t}: ${s.imps} imps`} style={{ width: 10, background: '#4F46E5', height: `${(s.imps/max)*100}%` }} />
      ))}
    </div>
  )
}



