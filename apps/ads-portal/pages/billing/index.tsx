import { useEffect, useState } from 'react'
import { api, getEmail } from '../../lib/api'
import Nav from '../../components/Nav'

type Balance = { available_cents: number }

export default function Billing() {
  const [balance, setBalance] = useState<Balance>({ available_cents: 0 })
  const [amount, setAmount] = useState(5000)
  const [status, setStatus] = useState('')
  useEffect(() => {
    const email = getEmail(); if (!email) return
    api<Balance>(`/ads/balance`, 'GET', { email }).then(setBalance).catch(()=>{})
  }, [])
  async function fund() {
    setStatus('Creating PaymentIntent...')
    const email = getEmail(); if (!email) { setStatus('Login first'); return }
    // In test mode backend may simulate success and increment virtual balance
    const res = await api<{ client_secret?: string; ok?: boolean }>(`/ads/fund`, 'POST', { email, amount_cents: Number(amount) })
    setStatus(res.client_secret ? 'Stripe client secret created (test mode). Balance will update shortly.' : 'Funded (virtual).')
    const bal = await api<Balance>(`/ads/balance`, 'GET', { email })
    setBalance(bal)
  }
  return (
    <main style={{ padding: 0, fontFamily: 'system-ui, -apple-system' }}>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Billing</h1>
        <div style={{ marginTop: 8, color: '#666' }}>Available balance: ${(balance.available_cents/100).toFixed(2)}</div>
        <div style={{ marginTop: 16, display: 'grid', gap: 8, maxWidth: 360 }}>
          <label>Amount (cents) <input type="number" value={amount} onChange={e=>setAmount(Number(e.target.value))} /></label>
          <button onClick={fund} style={{ padding: '10px 14px' }}>Add Funds</button>
          {status && <div style={{ color: '#0a6' }}>{status}</div>}
        </div>
      </div>
    </main>
  )
}


