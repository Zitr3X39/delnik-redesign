-- ============================================================
--  ДЕЛЬНИК · Доп. защита (v62)
--  Запустить в Supabase -> SQL Editor -> New query -> Run.
--  Что делает:
--   1) Запрет отзыва самому себе.
--   2) (ОПЦИЯ, включить перед релизом) запрет любой ЗАПИСИ
--      анонимным сессиям (кнопка "Тест вход" = signInAnonymously).
-- ============================================================

-- Помощник: текущая сессия НЕ анонимная (обычный вход по номеру).
create or replace function public.is_real_user()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false;
$$;

-- ---- 1) Запрет самоотзыва (author_id <> target_id) ----
drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews
  for insert to authenticated
  with check ( author_id = auth.uid()::text
               and author_id <> target_id );

drop policy if exists reviews_update on public.reviews;
create policy reviews_update on public.reviews
  for update to authenticated
  using ( author_id = auth.uid()::text )
  with check ( author_id = auth.uid()::text
               and author_id <> target_id );

-- ============================================================
--  2) ОПЦИЯ "боевой режим" — включить ПЕРЕД публикацией в сторы.
--     Полностью блокирует запись анонимным сессиям.
--     ВНИМАНИЕ: после этого кнопка "Тест вход" сможет только
--     смотреть ленту, но не публиковать заявки/отзывы/сообщения.
--     Раскомментируйте блок ниже (выделить -> Ctrl+/), затем Run.
-- ============================================================

-- drop policy if exists jobs_insert on public.shared_jobs;
-- create policy jobs_insert on public.shared_jobs
--   for insert to authenticated
--   with check ( data ->> 'employerId' = auth.uid()::text
--                and public.is_real_user() );
--
-- drop policy if exists profiles_insert on public.shared_profiles;
-- create policy profiles_insert on public.shared_profiles
--   for insert to authenticated
--   with check ( id = auth.uid()::text and public.is_real_user() );
--
-- drop policy if exists messages_insert on public.messages;
-- create policy messages_insert on public.messages
--   for insert to authenticated
--   with check ( sender_id = auth.uid()::text
--                and public.is_job_participant(job_id)
--                and public.is_real_user() );
--
-- -- И добавьте public.is_real_user() в reviews_insert выше при желании.
