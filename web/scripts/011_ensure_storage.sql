-- Create the 'images' bucket if it doesn't exist
insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do nothing;

-- Using DO block to safely create policies if they don't exist
do $$
begin
  -- Allow public access to the 'images' bucket
  if not exists (
    select 1 from pg_policies 
    where policyname = 'Public Access Images' 
    and tablename = 'objects' 
    and schemaname = 'storage'
  ) then
    create policy "Public Access Images"
      on storage.objects for select
      using ( bucket_id = 'images' );
  end if;

  -- Allow authenticated users to upload to the 'images' bucket
  if not exists (
    select 1 from pg_policies 
    where policyname = 'Authenticated Upload Images' 
    and tablename = 'objects' 
    and schemaname = 'storage'
  ) then
    create policy "Authenticated Upload Images"
      on storage.objects for insert
      with check ( bucket_id = 'images' and auth.role() = 'authenticated' );
  end if;
end $$;
