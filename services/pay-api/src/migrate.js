import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists pay_accounts(
  id serial primary key,
  user_id text unique,
  stripe_account_id text,
  status text,
  created_at timestamptz default now()
);
create table if not exists ledger_accounts(
  id serial primary key,
  user_id text,
  type text, -- 'creator'|'platform'|'tax'
  created_at timestamptz default now()
);
create table if not exists ledger_entries(
  id serial primary key,
  account_id int references ledger_accounts(id),
  amount numeric,
  currency text,
  direction text, -- 'debit'|'credit'
  reference_type text,
  reference_id text,
  created_at timestamptz default now()
);
create table if not exists entitlements(
  id serial primary key,
  user_id text,
  resource_id text,
  resource_type text,
  expires_at timestamptz
);
create table if not exists subscriptions(
  id serial primary key,
  user_id text,
  plan_id text,
  status text,
  current_period_end timestamptz,
  created_at timestamptz default now()
);
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Pay schema applied.')
process.exit(0)



