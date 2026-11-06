-- À exécuter après update-3.sql : notes et dépenses (admin uniquement)
create table if not exists notes(id bigint generated always as identity primary key,title text,body text,pinned bool default false,done bool default false,created_at timestamptz default now());
create table if not exists expenses(id bigint generated always as identity primary key,label text not null,amount int not null check(amount>=0),category text not null default 'Autre',spent_on date not null default current_date,note text,created_at timestamptz default now());
create index if not exists expenses_spent_on_idx on expenses(spent_on);
alter table notes enable row level security;alter table expenses enable row level security;
create policy a on notes for all using(is_admin()) with check(is_admin());
create policy a on expenses for all using(is_admin()) with check(is_admin());
