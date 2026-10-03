-- À exécuter après update-2.sql : histoires (accueil), livraison offerte configurable
create table if not exists stories(id bigint generated always as identity primary key,title text not null,kicker text,body text,image text,product_id bigint references products on delete set null,published bool default true,position int default 0,created_at timestamptz default now());
alter table stories enable row level security;
create policy r on stories for select using(published or is_admin());
create policy a on stories for all using(is_admin()) with check(is_admin());
-- Retire la livraison offerte "15 000 DA" posée par défaut (0 = désactivé, réglable dans l'admin)
update settings set value=jsonb_set(value,'{free_ship_from}','0') where key='store' and (value->>'free_ship_from')='15000';
update settings set value=jsonb_set(value,'{announcement}','""') where key='store' and value->>'announcement'='Livraison gratuite dès 15 000 DA';
create or replace function place_order(p_items jsonb,p_customer jsonb,p_use_points bool default false) returns jsonb language plpgsql security definer set search_path=public as $$
declare it jsonb;pr products;sp numeric;pc int;q int;qt int:=0;sub int:=0;lines jsonb:='[]';st jsonb;lo jsonb;pd int:=0;pu int:=0;sh int;tot int;rf text;ea int:=0;pts int;fa int;fq int;uid uuid:=auth.uid();on_ bool;
begin
 select value into st from settings where key='store';select value into lo from settings where key='loyalty';on_:=coalesce((lo->>'enabled')::bool,false);
 for it in select value from jsonb_array_elements(p_items) loop
  q:=(it->>'q')::int;if q<1 or q>20 then raise exception 'Quantité invalide';end if;qt:=qt+q;
  select * into pr from products where id=(it->>'id')::bigint and active;if not found then raise exception 'Produit indisponible';end if;
  select (s.v->>'price')::numeric into sp from jsonb_array_elements(pr.sizes) as s(v) where s.v->>'label'=it->>'size';if sp is null then raise exception 'Format invalide';end if;
  select coalesce(max(percent),0) into pc from discounts d where active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()) and (pr.id=any(product_ids) or category_id=pr.category_id);
  sub:=sub+round(sp*(100-pc)/100)*q;
  lines:=lines||jsonb_build_object('name',pr.name,'size',it->>'size','q',q,'price',round(sp*(100-pc)/100),'grav',it->>'grav');
 end loop;
 if p_use_points and uid is not null and on_ then select points into pts from profiles where id=uid;if pts>=(lo->>'redeem_cost')::int then pu:=(lo->>'redeem_cost')::int;pd:=round(sub*(lo->>'redeem_percent')::numeric/100);end if;end if;
 fa:=coalesce((st->>'free_ship_from')::int,0);fq:=coalesce((st->>'free_ship_min_items')::int,0);
 sh:=case when (fa>0 and sub-pd>=fa) or (fq>0 and qt>=fq) then 0 else coalesce((st->>'ship_fee')::int,0) end;tot:=sub-pd+sh;rf:='MB-'||upper(substr(md5(random()::text),1,6));
 if uid is not null and on_ then ea:=floor(tot/100.0)*coalesce((lo->>'earn_per_100da')::int,1);update profiles set points=points-pu+ea where id=uid;end if;
 insert into orders(ref,user_id,customer,items,subtotal,discount,points_used,ship,total) values(rf,uid,p_customer,lines,sub,pd,pu,sh,tot);
 return jsonb_build_object('ref',rf,'total',tot,'earned',ea);
end$$;
