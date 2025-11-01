import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists advertisers(
  id serial primary key,
  user_id text,
  name text not null,
  email text not null,
  status text default 'active',
  created_at timestamptz default now()
);
create table if not exists funding_sources(
  id serial primary key,
  advertiser_id int references advertisers(id),
  stripe_customer_id text,
  stripe_pm_id text,
  status text default 'active'
);
create table if not exists campaigns(
  id serial primary key,
  advertiser_id int references advertisers(id),
  name text,
  objective text,
  status text default 'paused',
  start_at timestamptz,
  end_at timestamptz,
  budget_cents int default 0,
  daily_cap_cents int default 0,
  cpm_floor_cents int default 0,
  geo text[], languages text[], devices text[], topics text[],
  created_at timestamptz default now()
);
create table if not exists line_items(
  id serial primary key,
  campaign_id int references campaigns(id),
  placement text,
  bid_cpm_cents int,
  frequency_cap int default 0,
  max_imps int default 0,
  targeting_json jsonb default '{}'::jsonb,
  status text default 'active'
);
create table if not exists creatives(
  id serial primary key,
  line_item_id int references line_items(id),
  type text,
  uri text,
  click_url text,
  width int,
  height int,
  duration_sec int,
  review_status text default 'pending',
  policy_labels text[] default '{}',
  created_at timestamptz default now()
);
create table if not exists serving_keys(
  id serial primary key,
  app text,
  placement text,
  key text unique,
  hmac_secret text,
  status text default 'active'
);
create table if not exists ad_requests(
  id serial primary key,
  key_id int references serving_keys(id),
  user_id text,
  video_id text,
  placement text,
  locale text,
  device text,
  ip_hash text,
  ua_hash text,
  ts timestamptz default now()
);
create table if not exists ad_impressions(
  id serial primary key,
  request_id int references ad_requests(id),
  creative_id int,
  campaign_id int,
  line_item_id int,
  video_id text,
  price_cpm_cents int,
  revenue_cents int,
  quartile text,
  ts timestamptz default now()
);
create table if not exists ad_clicks(
  id serial primary key,
  impression_id int references ad_impressions(id),
  ts timestamptz default now()
);
create table if not exists pacing_state(
  id serial primary key,
  line_item_id int references line_items(id),
  day date,
  spent_cents int default 0,
  imps int default 0,
  unique(line_item_id, day)
);
create table if not exists revshare_rules(
  id serial primary key,
  scope text,
  scope_id text,
  creator_bps int default 9000,
  platform_bps int default 1000,
  updated_at timestamptz default now()
);
create table if not exists floors(
  id serial primary key,
  country text,
  device text,
  category text,
  placement text,
  floor_cpm_cents int default 0,
  updated_at timestamptz default now()
);
create table if not exists settlements(
  id serial primary key,
  date date,
  creator_id text,
  revenue_cents int,
  details_json jsonb,
  status text default 'pending'
);
create table if not exists fraud_events(
  id serial primary key,
  request_id int,
  impression_id int,
  type text,
  score numeric,
  meta jsonb,
  ts timestamptz default now()
);

create index if not exists idx_li_status on line_items(status);
create index if not exists idx_req_key_ts on ad_requests(key_id, ts);
create index if not exists idx_imp_req on ad_impressions(request_id);
create index if not exists idx_click_imp on ad_clicks(impression_id);
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
await pool.query("alter table advertisers add column if not exists balance_cents int default 0")
console.log('Ads schema applied.')
process.exit(0)


