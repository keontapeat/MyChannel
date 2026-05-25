export type Init = { apiBase: string; token: string }
export type Referral = { code: string; url: string }

export class ChannelBoost {
  private static base = ''
  private static token = ''

  static init(cfg: Init) {
    this.base = cfg.apiBase.replace(/\/$/, '')
    this.token = cfg.token
  }

  private static async req(path: string, opts: RequestInit = {}) {
    const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}`, ...(opts.headers||{}) }
    const res = await fetch(`${this.base}${path}`, { ...opts, headers })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return res.json()
  }

  static async createReferral(userId: string, source = 'app'): Promise<Referral> {
    const q = new URLSearchParams({ user_id: userId, source })
    return this.req(`/referral/create?${q.toString()}`)
  }

  static async logInstall(p: { platform: string; locale: string; source?: string; campaign?: string; referral?: string }) {
    return this.req('/events/install', { method: 'POST', body: JSON.stringify(p) })
  }

  static async funnelStep(userId: string, step: 'signup'|'first_upload'|'invited_3') {
    return this.req('/events/funnel', { method: 'POST', body: JSON.stringify({ user_id: userId, step }) })
  }

  static async isReviewEligible(userId: string): Promise<{ eligible: boolean; reason?: string }> {
    return this.req('/reviews/eligible', { method: 'POST', body: JSON.stringify({ user_id: userId }) })
  }

  static async logReview(userId: string, deviceHash: string, outcome: 'shown'|'rated'|'skipped'|'never_ask') {
    return this.req('/reviews/log', { method: 'POST', body: JSON.stringify({ user_id: userId, device_hash: deviceHash, outcome }) })
  }

  static async getAsoMetadata(locale = 'en-US') {
    return this.req(`/aso/metadata?locale=${encodeURIComponent(locale)}`, { method: 'GET' })
  }
}

// ChannelMind + Pay helpers
export class MyChannelSDK {
  private base: string
  private token?: string
  constructor(apiBase: string, token?: string) {
    this.base = apiBase.replace(/\/$/, '')
    this.token = token
  }

  private async req<T>(path: string, method = 'GET', body?: any): Promise<T> {
    const headers: Record<string,string> = { 'Content-Type': 'application/json' }
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`
    const res = await fetch(`${this.base}${path}`, { method, headers, body: body? JSON.stringify(body): undefined })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return res.json()
  }

  // Search
  search(q: string, k = 10, videoId?: string) {
    const params = new URLSearchParams({ q, k: String(k) })
    if (videoId) params.append('video_id', videoId)
    return this.req<{ results: { video_id: string; t_start: number; t_end: number; score: number; keyframe_url: string; text_snippet: string }[] }>(`/search?${params.toString()}`)
  }
  chapters(videoId: string) { return this.req<{ chapters: any[] }>(`/chapters/${videoId}`) }
  tags(videoId: string) { return this.req<{ tags: any[] }>(`/tags/${videoId}`) }

  // Pay
  tip(toUserId: string, amount: number, currency = 'usd') { return this.req('/pay/tip', 'POST', { toUserId, amount, currency }) }
}


