import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists creator_metrics_daily(date date, user_id text, views int, watch_time_sec int, avg_watch_pct numeric, ctr numeric, subs_delta int, revenue_cents int);
create table if not exists video_retention_curve(video_id text, bucket_start_sec int, viewers_remaining_pct numeric);
create table if not exists transparency_events(id serial primary key, user_id text, video_id text, reason_code text, details_json jsonb, created_at timestamptz default now());
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('IQ schema applied.')
process.exit(0)



