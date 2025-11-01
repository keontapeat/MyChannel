import pkg from 'pg'
const { Pool } = pkg

const pool = new Pool({ connectionString: process.env.DATABASE_URL })

const LOCALES = ['en-US','es-ES','pt-BR','fr-FR','de-DE','it-IT','hi-IN','id-ID','ar','ja-JP','ko-KR','zh-CN']

const APP_NAME = 'MyChannel – AI Video'
const SUBTITLE = 'Watch. Upload. Go Viral.'
const KEYWORDS_LIST = ['video','ai video','short videos','streaming','social','creator','music','vlog','live']
const KEYWORDS = KEYWORDS_LIST.join(', ')
const PROMO = 'Powered by ChannelMind™ video AI.'
const BULLETS = [
  'Create and watch short-form videos with powerful AI tools.',
  'ChannelMind™ highlights key moments and trends for you.',
  'ChannelBoost™ optimizes your growth and referrals.',
  'Ultra-fast uploads and crisp playback.',
  'Discover new creators tailored to your taste.',
  'Built for creators: edit, caption, and share instantly.',
  'Privacy-first analytics and insights.'
]
const DESCRIPTION = BULLETS.map(b=>`• ${b}`).join('\n') + '\n\nDownload MyChannel and start creating today.'

const KEYWORDS_SEED = [
  { term: 'ai video', difficulty: 62, volume: 78 },
  { term: 'short videos', difficulty: 55, volume: 85 },
  { term: 'video editor', difficulty: 70, volume: 90 },
  { term: 'creator', difficulty: 40, volume: 50 },
  { term: 'streaming', difficulty: 65, volume: 88 },
  { term: 'vlog', difficulty: 45, volume: 60 },
  { term: 'live', difficulty: 50, volume: 75 },
]

function cap(s, n) { return (s||'').slice(0, n) }

async function seed() {
  // locales
  for (const code of LOCALES) {
    await pool.query('insert into app_locales(code, enabled) values($1,$2) on conflict (code) do nothing', [code, true])
  }

  // metadata: make en-US live, others draft (copy EN for now)
  for (const code of LOCALES) {
    const status = code === 'en-US' ? 'live' : 'draft'
    await pool.query(
      'insert into metadata_versions(locale_code,name,subtitle,description,keywords,promo_text,status) values($1,$2,$3,$4,$5,$6,$7)',
      [code, cap(APP_NAME,30), cap(SUBTITLE,30), DESCRIPTION, cap(KEYWORDS,100), PROMO, status]
    )
  }

  // keyword bank for en-US
  for (const k of KEYWORDS_SEED) {
    await pool.query('insert into keyword_bank(term, locale_code, difficulty, volume, topic, status) values($1,$2,$3,$4,$5,$6)',
      [k.term, 'en-US', k.difficulty, k.volume, 'video', 'active'])
  }

  console.log('ChannelBoost seed completed.')
  process.exit(0)
}

seed().catch(e=>{ console.error(e); process.exit(1) })



