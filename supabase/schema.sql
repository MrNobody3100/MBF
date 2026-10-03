-- MB Parfumerie — à exécuter une fois dans Supabase > SQL Editor
create table settings(key text primary key,value jsonb not null default '{}');
create table categories(id bigint generated always as identity primary key,name text not null,position int default 0);
create table products(id bigint generated always as identity primary key,category_id bigint references categories on delete set null,name text not null,tagline text,story text,composition jsonb default '{}',sizes jsonb not null default '[]',images text[] not null default '{}' check(cardinality(images)<=5),badge text,active bool default true,position int default 0,created_at timestamptz default now());
create table discounts(id bigint generated always as identity primary key,name text,percent int not null check(percent between 1 and 90),product_ids bigint[] default '{}',category_id bigint references categories on delete cascade,starts_at timestamptz,ends_at timestamptz,active bool default true);
create table profiles(id uuid primary key references auth.users on delete cascade,full_name text,phone text,wilaya text,address text,points int not null default 0);
create table admins(user_id uuid primary key references auth.users on delete cascade);
create table orders(id bigint generated always as identity primary key,ref text unique,user_id uuid references auth.users,customer jsonb,items jsonb,subtotal int,discount int default 0,points_used int default 0,ship int default 0,total int,status text default 'nouvelle',created_at timestamptz default now());
create function is_admin() returns bool language sql stable security definer set search_path=public as $$select exists(select 1 from admins where user_id=auth.uid())$$;
alter table settings enable row level security;alter table categories enable row level security;alter table products enable row level security;alter table discounts enable row level security;alter table profiles enable row level security;alter table admins enable row level security;alter table orders enable row level security;
create policy r on settings for select using(true);create policy r on categories for select using(true);create policy r on discounts for select using(active or is_admin());create policy r on products for select using(active or is_admin());
create policy a on settings for all using(is_admin()) with check(is_admin());create policy a on categories for all using(is_admin()) with check(is_admin());create policy a on products for all using(is_admin()) with check(is_admin());create policy a on discounts for all using(is_admin()) with check(is_admin());
create policy r on profiles for select using(id=auth.uid() or is_admin());create policy u on profiles for update using(id=auth.uid());
create policy r on orders for select using(user_id=auth.uid() or is_admin());create policy u on orders for update using(is_admin());
create policy r on admins for select using(user_id=auth.uid());
revoke update on profiles from authenticated;grant update(full_name,phone,wilaya,address) on profiles to authenticated;
create function new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into profiles(id,full_name,phone) values(new.id,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'phone');return new;end$$;
create trigger on_signup after insert on auth.users for each row execute function new_user();
create function adjust_points(uid uuid,delta int) returns void language plpgsql security definer set search_path=public as $$begin if not is_admin() then raise exception 'interdit';end if;update profiles set points=greatest(0,points+delta) where id=uid;end$$;
-- Commande: les prix, remises, points et livraison sont recalculés côté serveur
create function place_order(p_items jsonb,p_customer jsonb,p_use_points bool default false) returns jsonb language plpgsql security definer set search_path=public as $$
declare it jsonb;pr products;sp numeric;pc int;q int;sub int:=0;lines jsonb:='[]';st jsonb;lo jsonb;pd int:=0;pu int:=0;sh int;tot int;rf text;ea int:=0;pts int;uid uuid:=auth.uid();on_ bool;
begin
 select value into st from settings where key='store';select value into lo from settings where key='loyalty';on_:=coalesce((lo->>'enabled')::bool,false);
 for it in select value from jsonb_array_elements(p_items) loop
  q:=(it->>'q')::int;if q<1 or q>20 then raise exception 'Quantité invalide';end if;
  select * into pr from products where id=(it->>'id')::bigint and active;if not found then raise exception 'Produit indisponible';end if;
  select (s.v->>'price')::numeric into sp from jsonb_array_elements(pr.sizes) as s(v) where s.v->>'label'=it->>'size';if sp is null then raise exception 'Format invalide';end if;
  select coalesce(max(percent),0) into pc from discounts d where active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()) and (pr.id=any(product_ids) or category_id=pr.category_id);
  sub:=sub+round(sp*(100-pc)/100)*q;
  lines:=lines||jsonb_build_object('name',pr.name,'size',it->>'size','q',q,'price',round(sp*(100-pc)/100),'grav',it->>'grav');
 end loop;
 if p_use_points and uid is not null and on_ then select points into pts from profiles where id=uid;if pts>=(lo->>'redeem_cost')::int then pu:=(lo->>'redeem_cost')::int;pd:=round(sub*(lo->>'redeem_percent')::numeric/100);end if;end if;
 sh:=case when sub-pd>=coalesce((st->>'free_ship_from')::int,15000) then 0 else coalesce((st->>'ship_fee')::int,600) end;tot:=sub-pd+sh;rf:='MB-'||upper(substr(md5(random()::text),1,6));
 if uid is not null and on_ then ea:=floor(tot/100.0)*coalesce((lo->>'earn_per_100da')::int,1);update profiles set points=points-pu+ea where id=uid;end if;
 insert into orders(ref,user_id,customer,items,subtotal,discount,points_used,ship,total) values(rf,uid,p_customer,lines,sub,pd,pu,sh,tot);
 return jsonb_build_object('ref',rf,'total',tot,'earned',ea);
end$$;
grant execute on function place_order to anon,authenticated;
-- Réglages de départ (modifiables ensuite dans l'admin)
insert into settings values('store','{"announcement":"Livraison gratuite dès 15 000 DA","phone":"","whatsapp":"","instagram":"","facebook":"","email":"","free_ship_from":15000,"ship_fee":600}'),('loyalty','{"enabled":true,"earn_per_100da":1,"redeem_cost":100,"redeem_percent":10}');
insert into categories(name,position) values('Extrait de parfum',1),('Eau de parfum',2),('Accessoires',3);
insert into products(category_id,name,tagline,story,composition,sizes,images,badge,position) values
((select id from categories where name='Extrait de parfum'),'Santal Impérial d''Orient','Santal royal crémeux, ambre gris & vanille bourbon','Né d''un voyage à Mysore, ce flacon capture la chaleur des santals centenaires. Chaque extrait repose trois mois avant d''être scellé à la cire dorée.','{"top":"Bergamote, poivre rose, safran","heart":"Santal de Mysore, iris, jasmin","base":"Ambre gris, cuir doré, musc blanc"}','[{"label":"50 ml","price":16500},{"label":"100 ml","price":24500},{"label":"Coffret 100 ml","price":31000}]','{/assets/p/santal.jpg}','Édition limitée',1),
((select id from categories where name='Eau de parfum'),'Rose de Damas Dorée','Rose bulgare cueillie à l''aube et safran pur','Une rose récoltée avant le lever du soleil, quand ses huiles sont au plus précieux, posée sur un lit de musc blanc.','{"top":"Rose bulgare, safran","heart":"Rose de Damas, pivoine","base":"Musc, bois blond"}','[{"label":"50 ml","price":12900},{"label":"80 ml","price":18900}]','{/assets/p/rose.jpg}','Best seller',2),
((select id from categories where name='Extrait de parfum'),'Oud Noir Céleste','Oud cambodgien vieilli 12 ans, vanille noire fumée','Un oud rare, vieilli douze ans en fût, adouci par la vanille noire et l''encens pour un sillage de nuit.','{"top":"Encens, cardamome","heart":"Oud cambodgien, rose","base":"Vanille noire, ambre"}','[{"label":"50 ml","price":32000}]','{/assets/p/oud.jpg}','Rare millésime',3),
((select id from categories where name='Accessoires'),'Collier Porte-Parfum Or 18K','Fiole ciselée à la main','Un bijou qui porte votre extrait préféré partout, ciselé à la main par nos orfèvres.','{}','[{"label":"Unique","price":14200}]','{/assets/p/collier.jpg}','Orfèvrerie or 18K',4),
((select id from categories where name='Extrait de parfum'),'Ambre Majestueux & Cuir','Cuir blanc, ambre résineux, fève tonka','Un cuir blanc tanné à l''ancienne, enveloppé d''ambre résineux et de tonka grillée.','{"top":"Bergamote, pimentade","heart":"Cuir, ambre","base":"Tonka, bois de cèdre"}','[{"label":"100 ml","price":27500}]','{/assets/p/ambre.jpg}','Coup de cœur',5);
