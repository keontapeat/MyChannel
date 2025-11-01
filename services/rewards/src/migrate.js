import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists reward_ledger(id serial primary key, user_id text, delta_points int, reason text, ref_type text, ref_id text, created_at timestamptz default now());
create table if not exists reward_balances(user_id text primary key, points int default 0, updated_at timestamptz);
create table if not exists badges(id serial primary key, code text, name text, tier text, icon_uri text);
create table if not exists user_badges(id serial primary key, user_id text, badge_id int, granted_at timestamptz default now());
create table if not exists quests(id serial primary key, code text, name text, rules_json jsonb, reward_points int, active boolean default true);
create table if not exists quest_progress(id serial primary key, user_id text, quest_id int, progress_json jsonb, status text);
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Rewards schema applied.')
process.exit(0)



