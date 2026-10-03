-- À exécuter après schema.sql : stockage des photos produits (bucket public, écriture réservée à l'admin)
insert into storage.buckets(id,name,public) values('products','products',true) on conflict do nothing;
create policy "products read" on storage.objects for select using(bucket_id='products');
create policy "products admin insert" on storage.objects for insert with check(bucket_id='products' and public.is_admin());
create policy "products admin update" on storage.objects for update using(bucket_id='products' and public.is_admin());
create policy "products admin delete" on storage.objects for delete using(bucket_id='products' and public.is_admin());
