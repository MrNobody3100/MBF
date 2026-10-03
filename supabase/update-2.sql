-- À exécuter après schema.sql et admin.sql : changement de statut côté admin, avec remboursement des points si annulation
create or replace function set_order_status(oid bigint,st text) returns void language plpgsql security definer set search_path=public as $$
declare o orders;lo jsonb;ea int;
begin
 if not is_admin() then raise exception 'interdit';end if;
 select * into o from orders where id=oid;if not found then raise exception 'Commande introuvable';end if;
 if o.status='annulée' then raise exception 'Commande déjà annulée';end if;
 if st='annulée' and o.user_id is not null then
  select value into lo from settings where key='loyalty';
  ea:=case when coalesce((lo->>'enabled')::bool,false) then floor(o.total/100.0)*coalesce((lo->>'earn_per_100da')::int,1) else 0 end;
  update profiles set points=greatest(0,points+o.points_used-ea) where id=o.user_id;
 end if;
 update orders set status=st where id=oid;
end$$;
grant execute on function set_order_status to authenticated;
