import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists app_locales(
  id serial primary key,
  code text unique not null,
  enabled boolean default true
);
create table if not exists metadata_versions(
  id serial primary key,
  locale_code text not null,
  name text,
  subtitle text,
  description text,
  keywords text,
  promo_text text,
  status text default 'draft',
  created_at timestamptz default now()
);
create table if not exists keyword_bank(
  id serial primary key,
  term text,
  locale_code text,
  difficulty int,
  volume int,
  topic text,
  status text default 'active'
);
create table if not exists keyword_set(
  id serial primary key,
  locale_code text,
  slot text,
  terms text[],
  created_at timestamptz default now(),
  live_from timestamptz
);
create table if not exists referral_code(
  id serial primary key,
  code text unique,
  creator_user_id text,
  source text,
  campaign text,
  installs int default 0,
  conversions int default 0,
  created_at timestamptz default now()
);
create table if not exists review_prompt_log(
  id serial primary key,
  user_id text,
  device_hash text,
  last_prompt_at timestamptz,
  outcome text
);
create table if not exists install_events(
  id serial primary key,
  platform text,
  locale_code text,
  source text,
  campaign text,
  referred_by_code text,
  created_at timestamptz default now()
);
create table if not exists referral_clicks(
  id serial primary key,
  code text not null,
  user_agent text,
  ip text,
  created_at timestamptz default now()
);
create table if not exists funnel_events(
  id serial primary key,
  user_id text,
  step text,
  created_at timestamptz default now()
);
create table if not exists metrics_daily(
  date date primary key,
  locale_code text,
  installs int default 0,
  signups int default 0,
  uploads int default 0,
  d1_retention numeric,
  reviews int default 0,
  avg_rating numeric
);
create index if not exists idx_referral_clicks_code on referral_clicks(code);
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('ChannelBoost schema applied.')
process.exit(0)


