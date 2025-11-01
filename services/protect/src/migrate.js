import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists policies(id serial primary key, code text, name text, severity text, region_scope text[] , created_at timestamptz default now());
create table if not exists rights_owner(id serial primary key, org_name text, contact_email text, verified boolean default false);
create table if not exists reference_fingerprint(id serial primary key, rights_owner_id int, type text, hash text unique, meta jsonb, created_at timestamptz default now());
create table if not exists claims(id serial primary key, video_id text, rights_owner_id int, policy_id int, status text, evidence_uri text, created_at timestamptz default now(), updated_at timestamptz);
create table if not exists dmca_takedowns(id serial primary key, video_id text, reporter_email text, status text, deadlines jsonb, audit_json jsonb, created_at timestamptz default now());
create table if not exists abuse_events(id serial primary key, user_id text, device_hash text, type text, score numeric, meta jsonb, created_at timestamptz default now());
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Protect schema applied.')
process.exit(0)



