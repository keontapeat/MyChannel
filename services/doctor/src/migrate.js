import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists incidents(id serial primary key, title text, severity text, status text, created_at timestamptz default now());
create table if not exists signals(id serial primary key, kind text, value numeric, observed_at timestamptz default now());
create table if not exists actions(id serial primary key, incident_id int, action text, actor text, created_at timestamptz default now());
create table if not exists slo_defs(id serial primary key, service text, objective_pct numeric, window_min int);
create table if not exists synthetic_checks(id serial primary key, name text, path text, expected_status int, interval_sec int);
create table if not exists chaos_experiments(id serial primary key, name text, type text, params jsonb, enabled boolean default false);
create table if not exists audit_log(id serial primary key, entity text, data jsonb, hash text, created_at timestamptz default now());
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Doctor schema applied.')
process.exit(0)



