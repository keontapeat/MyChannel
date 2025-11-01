export type SourceCode = 'PEXELS'|'PIXABAY'|'ARCHIVE'|'WIKI'

export interface SourceAssetMeta {
  externalId: string
  title: string
  author?: string
  sourceUrl: string
  downloadUrl: string
  licenseCode: 'CC0'|'PD'|'CC_BY'|'OTHER'
  licenseUrl?: string
  requiresAttribution: boolean
  allowsCommercial: boolean
}

export interface SourceAdapter {
  search(opts: { query?: string, perPage?: number, page?: number }): Promise<SourceAssetMeta[]>
}

export function getAdapter(source: SourceCode): SourceAdapter {
  switch (source) {
    case 'PEXELS': return new PexelsAdapter()
    case 'PIXABAY': return new PixabayAdapter()
    case 'ARCHIVE': return new ArchiveAdapter()
    case 'WIKI': return new WikiAdapter()
  }
}

class PexelsAdapter implements SourceAdapter {
  async search({ query = 'nature', perPage = 10, page = 1 }): Promise<SourceAssetMeta[]> {
    if (!process.env.PEXELS_API_KEY) {
      return []
    }
    const url = `https://api.pexels.com/videos/search?query=${encodeURIComponent(query)}&per_page=${perPage}&page=${page}`
    const res = await fetch(url, { headers: { Authorization: process.env.PEXELS_API_KEY! } })
    if (!res.ok) return []
    const json: any = await res.json()
    const out: SourceAssetMeta[] = (json.videos || []).map((v: any) => {
      const file = (v.video_files || []).sort((a: any, b: any) => (b.width*b.height)-(a.width*a.height))[0]
      return {
        externalId: String(v.id),
        title: v.user?.name ? `${v.user.name} - ${v.url?.split('/').slice(-2,-1)[0] ?? 'Pexels Video'}` : 'Pexels Video',
        author: v.user?.name,
        sourceUrl: v.url,
        downloadUrl: file?.link ?? v.url,
        licenseCode: 'OTHER', // Pexels License (commercial use allowed)
        licenseUrl: 'https://www.pexels.com/license/',
        requiresAttribution: false,
        allowsCommercial: true,
      }
    })
    return out
  }
}

class PixabayAdapter implements SourceAdapter {
  async search({ query = 'city', perPage = 10, page = 1 }): Promise<SourceAssetMeta[]> {
    if (!process.env.PIXABAY_API_KEY) {
      return []
    }
    return []
  }
}

class ArchiveAdapter implements SourceAdapter {
  async search({ query = 'public domain', perPage = 10, page = 1 }): Promise<SourceAssetMeta[]> {
    return []
  }
}

class WikiAdapter implements SourceAdapter {
  async search({ query = 'video', perPage = 10, page = 1 }): Promise<SourceAssetMeta[]> {
    return []
  }
}


