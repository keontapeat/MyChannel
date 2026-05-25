export const ADS_BASE = process.env.NEXT_PUBLIC_ADS_BASE_URL || 'http://localhost:9093'

export async function api<T>(path: string, method: string = 'GET', body?: any): Promise<T> {
  const res = await fetch(`${ADS_BASE}${path}` + (method === 'GET' && body ? `?${new URLSearchParams(body).toString()}` : ''), {
    method,
    headers: { 'content-type': 'application/json' },
    body: method !== 'GET' && body ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) throw new Error(`${method} ${path} failed: ${res.status}`)
  return (await res.json()) as T
}

export function getEmail(): string {
  if (typeof window === 'undefined') return ''
  return localStorage.getItem('adsEmail') || ''
}

export function setEmail(email: string) {
  if (typeof window === 'undefined') return
  localStorage.setItem('adsEmail', email)
}



