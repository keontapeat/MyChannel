import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists nodes(id serial primary key, kind text, key text, props_json jsonb);
create table if not exists edges(id serial primary key, src_id int, dst_id int, relation text, weight numeric, props_json jsonb, created_at timestamptz default now());
create table if not exists exports(id serial primary key, kind text, uri text, checksum text, created_at timestamptz default now());
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Core Vault schema applied.')
process.exit(0)



