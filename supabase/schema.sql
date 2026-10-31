-- Debashis Cycle Store — Supabase schema
-- Supabase Dashboard → SQL Editor → New query → এটা paste করে Run চাপুন।

create table if not exists products (
  id uuid primary key,
  name text not null,
  cat text,
  unit text default 'পিস',
  cost numeric not null default 0,
  sell numeric not null default 0,
  stock numeric not null default 0,
  min numeric not null default 0
);

create table if not exists customers (
  id uuid primary key,
  name text not null,
  phone text,
  address text
);

create table if not exists suppliers (
  id uuid primary key,
  name text not null,
  phone text,
  address text
);

create sequence if not exists inv_seq;

create table if not exists sales (
  id uuid primary key,
  inv text unique,
  date date not null,
  "customerId" uuid,
  "customerName" text,
  items jsonb not null default '[]',
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null default 0,
  paid numeric not null default 0,
  due numeric not null default 0,
  "createdBy" uuid default auth.uid(),
  "createdAt" timestamptz default now()
);

create table if not exists purchases (
  id uuid primary key,
  date date not null,
  "supplierId" uuid,
  "supplierName" text,
  items jsonb not null default '[]',
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null default 0,
  paid numeric not null default 0,
  due numeric not null default 0,
  "createdBy" uuid default auth.uid(),
  "createdAt" timestamptz default now()
);

create table if not exists payments (
  id uuid primary key,
  date date not null,
  type text not null check (type in ('c','s')),
  "partyId" uuid not null,
  amount numeric not null,
  "createdBy" uuid default auth.uid()
);

create table if not exists expenses (
  id uuid primary key,
  date date not null,
  cat text,
  amount numeric not null,
  note text,
  "createdBy" uuid default auth.uid()
);

create table if not exists settings (
  id int primary key check (id = 1),
  shop text,
  phone text,
  address text
);
insert into settings(id, shop) values (1, 'দেবাশীষ সাইকেল স্টোর') on conflict do nothing;

create index if not exists sales_date_idx on sales(date);
create index if not exists purchases_date_idx on purchases(date);
create index if not exists payments_date_idx on payments(date);
create index if not exists expenses_date_idx on expenses(date);

-- ---------- atomic functions (স্টক ও ইনভয়েস একসাথে সেভ হয়) ----------
create or replace function create_sale(r jsonb) returns text
language plpgsql as $$
declare invno text; it jsonb;
begin
  invno := 'INV-' || lpad(nextval('inv_seq')::text, 4, '0');
  insert into sales(id, inv, date, "customerId", "customerName", items, subtotal, discount, total, paid, due)
  values ((r->>'id')::uuid, invno, (r->>'date')::date, nullif(r->>'customerId','')::uuid, r->>'customerName',
          r->'items', (r->>'subtotal')::numeric, (r->>'discount')::numeric, (r->>'total')::numeric,
          (r->>'paid')::numeric, (r->>'due')::numeric);
  for it in select * from jsonb_array_elements(r->'items') loop
    update products set stock = stock - (it->>'qty')::numeric where id = (it->>'pid')::uuid;
  end loop;
  return invno;
end $$;

create or replace function create_purchase(r jsonb) returns void
language plpgsql as $$
declare it jsonb;
begin
  insert into purchases(id, date, "supplierId", "supplierName", items, subtotal, discount, total, paid, due)
  values ((r->>'id')::uuid, (r->>'date')::date, nullif(r->>'supplierId','')::uuid, r->>'supplierName',
          r->'items', (r->>'subtotal')::numeric, (r->>'discount')::numeric, (r->>'total')::numeric,
          (r->>'paid')::numeric, (r->>'due')::numeric);
  for it in select * from jsonb_array_elements(r->'items') loop
    update products
       set stock = stock + (it->>'qty')::numeric, cost = (it->>'price')::numeric
     where id = (it->>'pid')::uuid;
  end loop;
end $$;

create or replace function cancel_sale(did uuid) returns void
language plpgsql as $$
declare it jsonb; s sales;
begin
  select * into s from sales where id = did;
  if not found then return; end if;
  for it in select * from jsonb_array_elements(s.items) loop
    update products set stock = stock + (it->>'qty')::numeric where id = (it->>'pid')::uuid;
  end loop;
  delete from sales where id = did;
end $$;

create or replace function cancel_purchase(did uuid) returns void
language plpgsql as $$
declare it jsonb; p purchases;
begin
  select * into p from purchases where id = did;
  if not found then return; end if;
  for it in select * from jsonb_array_elements(p.items) loop
    update products set stock = stock - (it->>'qty')::numeric where id = (it->>'pid')::uuid;
  end loop;
  delete from purchases where id = did;
end $$;

-- ---------- Row Level Security: শুধু লগইন করা ইউজার ডাটা দেখতে/বদলাতে পারবে ----------
do $$
declare t text;
begin
  foreach t in array array['products','customers','suppliers','sales','purchases','payments','expenses','settings']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "auth all" on %I', t);
    execute format('create policy "auth all" on %I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

grant usage, select on sequence inv_seq to authenticated;
revoke all on all tables in schema public from anon;
