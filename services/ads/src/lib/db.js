import pkg from 'pg'
const { Pool } = pkg

export const pool = new Pool({ connectionString: process.env.DATABASE_URL })

export async function query(text, params) {
  const start = Date.now()
  const res = await pool.query(text, params)
  const ms = Date.now() - start
  if (process.env.LOG_SQL === '1') console.log('[sql]', ms + 'ms', text)
  return res
}



