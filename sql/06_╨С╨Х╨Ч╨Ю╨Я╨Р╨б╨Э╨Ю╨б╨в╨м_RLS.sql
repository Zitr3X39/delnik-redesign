-- ============================================================
--  БЕЗОПАСНОСТЬ (RLS) для проекта «Рабочий»
--  Запустить ЦЕЛИКОМ в Supabase -> SQL Editor -> Run.
--  Закрывает:
--   • чтение чужих переписок (messages) — только участники заявки;
--   • редактирование/удаление чужих заявок и профилей;
--   • подмену автора отзывов/жалоб.
--  Важно: id пользователей = auth.uid() (так же хранится в коде).
-- ============================================================

-- Вспомогательная функция: текущий пользователь — участник заявки
-- (владелец или тот, кто откликнулся).
create or replace function public.is_job_participant(p_job_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.shared_jobs j
    where j.id = p_job_id
      and (
        j.data->>'employerId' = auth.uid()::text
        or (j.data->'applicants')::jsonb ? auth.uid()::text
        or (j.data->'rejectedApplicants')::jsonb ? auth.uid()::text
      )
  );
$$;

-- ---------- messages: только участники заявки ----------
alter table public.messages enable row level security;

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using ( public.is_job_participant(job_id) );

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check ( sender_id = auth.uid()::text and public.is_job_participant(job_id) );

-- update нужен, чтобы отмечать входящие как прочитанные (read_at).
drop policy if exists messages_update on public.messages;
create policy messages_update on public.messages
  for update to authenticated
  using ( public.is_job_participant(job_id) )
  with check ( public.is_job_participant(job_id) );

drop policy if exists messages_delete on public.messages;
create policy messages_delete on public.messages
  for delete to authenticated
  using ( public.is_job_participant(job_id) );

-- ---------- shared_profiles: читать все, менять — только свой ----------
alter table public.shared_profiles enable row level security;

drop policy if exists profiles_select on public.shared_profiles;
create policy profiles_select on public.shared_profiles
  for select to authenticated
  using ( true );

drop policy if exists profiles_insert on public.shared_profiles;
create policy profiles_insert on public.shared_profiles
  for insert to authenticated
  with check ( id = auth.uid()::text );

drop policy if exists profiles_update on public.shared_profiles;
create policy profiles_update on public.shared_profiles
  for update to authenticated
  using ( id = auth.uid()::text )
  with check ( id = auth.uid()::text );

-- ---------- reviews: читать все, писать — только от своего имени ----------
alter table public.reviews enable row level security;

drop policy if exists reviews_select on public.reviews;
create policy reviews_select on public.reviews
  for select to authenticated
  using ( true );

drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews
  for insert to authenticated
  with check ( author_id = auth.uid()::text );

drop policy if exists reviews_update on public.reviews;
create policy reviews_update on public.reviews
  for update to authenticated
  using ( author_id = auth.uid()::text )
  with check ( author_id = auth.uid()::text );

drop policy if exists reviews_delete on public.reviews;
create policy reviews_delete on public.reviews
  for delete to authenticated
  using ( author_id = auth.uid()::text );

-- ---------- reports: только создание от своего имени (читать нельзя) ----------
alter table public.reports enable row level security;

drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
  for insert to authenticated
  with check ( reporter_id = auth.uid()::text );
-- SELECT-политики нет — жалобы не видны обычным пользователям.
-- Смотреть жалобы можно через панель Supabase (service_role обходит RLS).

-- ---------- shared_jobs: лента видна всем, создание/удаление — владелец ----------
alter table public.shared_jobs enable row level security;

drop policy if exists jobs_select on public.shared_jobs;
create policy jobs_select on public.shared_jobs
  for select to authenticated
  using ( true );

drop policy if exists jobs_insert on public.shared_jobs;
create policy jobs_insert on public.shared_jobs
  for insert to authenticated
  with check ( data->>'employerId' = auth.uid()::text );

drop policy if exists jobs_delete on public.shared_jobs;
create policy jobs_delete on public.shared_jobs
  for delete to authenticated
  using ( data->>'employerId' = auth.uid()::text );

-- update разрешён всем авторизованным (нужно для отклика),
-- но целостность защищает триггер ниже.
drop policy if exists jobs_update on public.shared_jobs;
create policy jobs_update on public.shared_jobs
  for update to authenticated
  using ( true )
  with check ( true );

-- Триггер: посторонний не может присвоить заявку, изменить её суть
-- или удалить чужие отклики. Разрешает только добавить/убрать СЕБЯ.
create or replace function public.guard_shared_jobs_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid text := auth.uid()::text;
begin
  -- Владелец меняет свою заявку как угодно.
  if new.data->>'employerId' = uid then
    return new;
  end if;

  -- Нельзя сменить владельца чужой заявки.
  if new.data->>'employerId' is distinct from old.data->>'employerId' then
    raise exception 'Нельзя изменять владельца заявки';
  end if;

  -- Нельзя менять ключевые поля чужой заявки.
  if (new.data->>'title')         is distinct from (old.data->>'title')
  or (new.data->>'description')   is distinct from (old.data->>'description')
  or (new.data->>'address')       is distinct from (old.data->>'address')
  or (new.data->>'payPerHour')    is distinct from (old.data->>'payPerHour')
  or (new.data->>'workersNeeded') is distinct from (old.data->>'workersNeeded')
  or (new.data->>'date')          is distinct from (old.data->>'date') then
    raise exception 'Нельзя редактировать чужую заявку';
  end if;

  -- Посторонний может убрать из откликнувшихся только СЕБЯ.
  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(old.data->'applicants', '[]'::jsonb)) o(val)
    where not ((new.data->'applicants')::jsonb ? o.val)
      and o.val <> uid
  ) then
    raise exception 'Нельзя удалять чужие отклики';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_shared_jobs_update on public.shared_jobs;
create trigger trg_guard_shared_jobs_update
  before update on public.shared_jobs
  for each row execute function public.guard_shared_jobs_update();

-- ============================================================
--  ГОТОВО. После Run проверьте, что приложение работает:
--  — отклик на заявку, отмена отклика, чат, отзывы, жалобы.
-- ============================================================
