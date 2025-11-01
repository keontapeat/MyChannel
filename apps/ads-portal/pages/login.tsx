import { useState } from 'react'
import { useRouter } from 'next/router'
import { setEmail } from '../lib/api'

export default function Login() {
  const [email, setEmailState] = useState('brand@example.com')
  const router = useRouter()
  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system' }}>
      <h1>Sign in to Ads</h1>
      <p style={{ color: '#666' }}>Use your MyChannel account email</p>
      <div style={{ marginTop: 16 }}>
        <input value={email} onChange={e=>setEmailState(e.target.value)} placeholder="email" style={{ padding: 8, width: 280 }} />
      </div>
      <button onClick={()=>{ setEmail(email); router.push('/campaigns') }} style={{ marginTop: 16, padding: '10px 14px' }}>Continue</button>
    </main>
  )
}



