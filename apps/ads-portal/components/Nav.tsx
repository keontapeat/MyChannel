import Link from 'next/link'
import { useEffect, useState } from 'react'
import { getEmail, setEmail } from '../lib/api'

export default function Nav() {
  const [email, setEmailState] = useState('')
  useEffect(() => { setEmailState(getEmail()) }, [])
  function logout() { setEmail(''); setEmailState('') }
  return (
    <nav style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 24px', borderBottom: '1px solid #eee', fontFamily: 'system-ui, -apple-system' }}>
      <div style={{ display: 'flex', gap: 16 }}>
        <Link href="/campaigns">Campaigns</Link>
        <Link href="/campaigns/new">New</Link>
        <Link href="/billing">Billing</Link>
      </div>
      <div>
        {email ? (
          <span>
            <span style={{ marginRight: 12, color: '#555' }}>{email}</span>
            <button onClick={logout} style={{ padding: '6px 10px' }}>Sign out</button>
          </span>
        ) : (
          <Link href="/login">Sign in</Link>
        )}
      </div>
    </nav>
  )
}



