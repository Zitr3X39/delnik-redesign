begin;
alter table public.messages add column if not exists read_at timestamptz;
drop policy if exists messages_update_read on public.messages;
create or replace function public.validate_message_read_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $function$
begin
  if new.id <> old.id
     or new.job_id <> old.job_id
     or new.thread_id <> old.thread_id
     or new.sender_id <> old.sender_id
     or new.sender_name <> old.sender_name
     or new.text <> old.text
     or new.created_at <> old.created_at then
    raise exception 'Only read_at can be updated';
  end if;
  return new;
end;
$function$;
drop trigger if exists protect_message_read_update on public.messages;
create trigger protect_message_read_update
before update on public.messages
for each row execute function public.validate_message_read_update();
create policy messages_update_read
on public.messages
for update
to authenticated
using (
  sender_id <> auth.uid()::text
  and exists (
    select 1
    from public.shared_jobs as j
    where j.id = messages.job_id
      and (
        messages.thread_id = auth.uid()::text
        or j.data->>'employerId' = auth.uid()::text
      )
  )
)
with check (
  sender_id <> auth.uid()::text
  and exists (
    select 1
    from public.shared_jobs as j
    where j.id = messages.job_id
      and (
        messages.thread_id = auth.uid()::text
        or j.data->>'employerId' = auth.uid()::text
      )
  )
);
commit;
