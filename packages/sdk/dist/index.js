export class ChannelBoost {
    static init(cfg) {
        this.base = cfg.apiBase.replace(/\/$/, '');
        this.token = cfg.token;
    }
    static async req(path, opts = {}) {
        const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}`, ...(opts.headers || {}) };
        const res = await fetch(`${this.base}${path}`, { ...opts, headers });
        if (!res.ok)
            throw new Error(`HTTP ${res.status}`);
        return res.json();
    }
    static async createReferral(userId, source = 'app') {
        const q = new URLSearchParams({ user_id: userId, source });
        return this.req(`/referral/create?${q.toString()}`);
    }
    static async logInstall(p) {
        return this.req('/events/install', { method: 'POST', body: JSON.stringify(p) });
    }
    static async funnelStep(userId, step) {
        return this.req('/events/funnel', { method: 'POST', body: JSON.stringify({ user_id: userId, step }) });
    }
    static async isReviewEligible(userId) {
        return this.req('/reviews/eligible', { method: 'POST', body: JSON.stringify({ user_id: userId }) });
    }
    static async logReview(userId, deviceHash, outcome) {
        return this.req('/reviews/log', { method: 'POST', body: JSON.stringify({ user_id: userId, device_hash: deviceHash, outcome }) });
    }
    static async getAsoMetadata(locale = 'en-US') {
        return this.req(`/aso/metadata?locale=${encodeURIComponent(locale)}`, { method: 'GET' });
    }
}
ChannelBoost.base = '';
ChannelBoost.token = '';
// ChannelMind + Pay helpers
export class MyChannelSDK {
    constructor(apiBase, token) {
        this.base = apiBase.replace(/\/$/, '');
        this.token = token;
    }
    async req(path, method = 'GET', body) {
        const headers = { 'Content-Type': 'application/json' };
        if (this.token)
            headers['Authorization'] = `Bearer ${this.token}`;
        const res = await fetch(`${this.base}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
        if (!res.ok)
            throw new Error(`HTTP ${res.status}`);
        return res.json();
    }
    // Search
    search(q, k = 10, videoId) {
        const params = new URLSearchParams({ q, k: String(k) });
        if (videoId)
            params.append('video_id', videoId);
        return this.req(`/search?${params.toString()}`);
    }
    chapters(videoId) { return this.req(`/chapters/${videoId}`); }
    tags(videoId) { return this.req(`/tags/${videoId}`); }
    // Pay
    tip(toUserId, amount, currency = 'usd') { return this.req('/pay/tip', 'POST', { toUserId, amount, currency }); }
}
