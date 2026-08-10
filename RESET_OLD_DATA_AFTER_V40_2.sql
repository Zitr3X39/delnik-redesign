-- Run only AFTER deploying v40.2 to Netlify and closing old app versions.
begin;
delete from public.messages;
delete from public.reviews;
delete from public.shared_jobs;
update public.shared_profiles
set data = jsonb_set(data, '{favorites}', '[]'::jsonb, true),
    updated_at = now();
commit;
