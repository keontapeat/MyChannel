import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists oauth_clients(id serial primary key, name text, client_id text, client_secret_hash text, redirect_uris text[], scopes text[]);
create table if not exists oauth_tokens(id serial primary key, client_id int, user_id text, scope text, expires_at timestamptz);
create table if not exists api_keys(id serial primary key, owner_user_id text, key_hash text, scopes text[], created_at timestamptz default now(), last_used_at timestamptz, rate_limit_per_min int);
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Connect schema applied.')
process.exit(0)



