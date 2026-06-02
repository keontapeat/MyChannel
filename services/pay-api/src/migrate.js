import pkg from 'pg'
const { Pool } = pkg

const ddl = `
create table if not exists pay_accounts(
  id serial primary key,
  user_id text unique not null,
  stripe_account_id text,
  status text default 'pending',
  auto_payout_enabled boolean default false,
  auto_payout_threshold integer default 10000,
  last_payout_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists ledger_accounts(
  id serial primary key,
  user_id text not null,
  type text not null, -- 'creator'|'platform'|'tax'
  created_at timestamptz default now(),
  unique(user_id, type)
);

create table if not exists ledger_entries(
  id serial primary key,
  account_id int not null references ledger_accounts(id),
  amount numeric(20,0) not null,   -- integer cents, never float dollars
  currency text not null default 'usd',
  direction text not null check (direction in ('credit','debit')),
  reference_type text,             -- 'tip'|'ads'|'payout'|'membership'|...
  reference_id text,
  metadata jsonb,
  created_at timestamptz default now()
);
create index if not exists ledger_entries_account_id_idx on ledger_entries(account_id);
create index if not exists ledger_entries_reference_type_idx on ledger_entries(reference_type);
create index if not exists ledger_entries_created_at_idx on ledger_entries(created_at);

create table if not exists entitlements(
  id serial primary key,
  user_id text not null,
  resource_id text not null,
  resource_type text not null,
  expires_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists subscriptions(
  id serial primary key,
  user_id text not null,
  plan_id text not null,
  status text not null default 'active',
  current_period_end timestamptz,
  created_at timestamptz default now()
);
`

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
await pool.query(ddl)
console.log('Pay schema applied.')
process.exit(0)



