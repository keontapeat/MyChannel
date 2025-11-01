export type InitOptions = { baseUrl: string; key: string; user?: { id?: string } }
export type ServeRequest = { placement: string; locale?: string; device?: string; videoContext?: { videoId?: string; tags?: string[]; topic?: string } }
export type ServeResponse = { fill: 'direct'|'network'|'none'; creative?: { uri: string; clickUrl: string; duration: number }; tracking?: { impUrl: string; q25Url: string; q50Url: string; q75Url: string; q100Url: string; clickUrl: string } }

let cfg: InitOptions

export function init(options: InitOptions) { cfg = options }

export async function requestAd(req: ServeRequest): Promise<ServeResponse> {
  if (!cfg) throw new Error('ads sdk not initialized')
  const res = await fetch(`${cfg.baseUrl}/ads/serve`, { method: 'POST', headers: { 'content-type':'application/json' }, body: JSON.stringify({ key: cfg.key, user: cfg.user, ...req }) })
  if (!res.ok) throw new Error(`serve failed ${res.status}`)
  return res.json()
}

export async function trackQuartile(url: string) { try { await fetch(url, { method: 'POST' }) } catch (_) {} }
export async function trackClick(url: string) { try { await fetch(url, { method: 'POST' }) } catch (_) {} }



