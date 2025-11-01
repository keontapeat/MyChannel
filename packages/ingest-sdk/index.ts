export class IngestClient {
  constructor(private base: string) {}
  async pull(source: 'PEXELS'|'PIXABAY'|'ARCHIVE'|'WIKI', query?: string, perPage = 5, pages = 1) {
    const res = await fetch(`${this.base}/ingest/source/pull`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ source, query, perPage, pages }) })
    if (!res.ok) throw new Error(`pull failed ${res.status}`)
    return res.json()
  }
}



