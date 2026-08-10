-- ============================================================
--  ДЕЛЬНИК · Серверные лимиты против спама (v62)
--  Работают НА СЕРВЕРЕ — их НЕЛЬЗЯ обойти, взломав клиента.
--
--  Два уровня защиты:
--   • НА КАЖДОГО ПОЛЬЗОВАТЕЛЯ (продуктовые правила):
--       – заявки:  3  новых / 24ч
--       – отклики: 10 / 24ч
--       – отзывы: 30 новых / 24ч
--       – сообщения: 50 / минуту (антифлуд на каждого отправителя)
--   • ГЛОБАЛЬНЫЙ ПРЕДОХРАНИТЕЛЬ (вся система, защита от массовой атаки):
--       – заявки: 70  новых / 24ч на ВСЕХ
--       – отзывы: 140 новых / 24ч на ВСЕХ
--
--  ПРИМЕЧАНИЕ про сообщения: 50/мин сделаны НА КАЖДОГО отправителя,
--  а НЕ общим лимитом: общий лимит 50/мин на весь чат заблокировал бы
--  общение уже при 10-15 активных пользователях. Пер-пользовательский
--  антифлуд защищает от спам-бота и при этом не мешает живому чату.
--
--  Запустить в Supabase -> SQL Editor -> New query -> Run.
-- ============================================================

-- Журнал действий (только для подсчёта лимитов).
create table if not exists public.rate_events (
  id bigserial primary key,
  user_id text not null,
  action text not null,
  created_at timestamptz not null default now()
);
create index if not exists rate_events_lookup
  on public.rate_events (user_id, action, created_at);

-- Клиенту к этой таблице доступа НЕТ (RLS вкл, политик нет).
-- Пишут только триггеры (security definer), которые RLS обходят.
alter table public.rate_events enable row level security;

-- Универсальный ограничитель.
create or replace function public.check_rate_limit(
  p_user text, p_action text, p_max int, p_window interval)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cnt int;
begin
  if p_user is null or p_user = '' then
    return;
  end if;
  select count(*) into cnt
    from public.rate_events
    where user_id = p_user
      and action = p_action
      and created_at > now() - p_window;
  if cnt >= p_max then
    raise exception 'RATE_LIMIT_%: слишком много действий, попробуйте позже', p_action;
  end if;
  insert into public.rate_events(user_id, action) values (p_user, p_action);
end;
$$;

-- ---- ЗАЯВКИ: 3/24ч на пользователя + 70/24ч глобально ----
-- Считаем только НОВЫЕ заявки; обновления (upsert) лимит не тратят.
create or replace function public.tg_limit_jobs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.shared_jobs where id = new.id) then
    return new; -- обновление существующей заявки
  end if;
  perform public.check_rate_limit(
    new.data ->> 'employerId', 'job', 3, interval '24 hours');
  perform public.check_rate_limit(
    '__ALL__', 'job_global', 70, interval '24 hours');
  return new;
end;
$$;
drop trigger if exists limit_jobs on public.shared_jobs;
create trigger limit_jobs
  before insert on public.shared_jobs
  for each row execute function public.tg_limit_jobs();

-- ---- ОТКЛИКИ: 10/24ч на пользователя ----
-- Отклик = добавление своего id в data.applicants через UPDATE заявки.
-- Считаем только момент, когда текущий пользователь ВПЕРВЫЕ появляется
-- в списке (отмена отклика лимит на сервере не возвращает).
create or replace function public.tg_limit_applies()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid text := auth.uid()::text;
  in_old boolean;
  in_new boolean;
begin
  if uid is null or uid = '' then
    return new;
  end if;
  in_old := coalesce((old.data -> 'applicants') @> to_jsonb(uid), false);
  in_new := coalesce((new.data -> 'applicants') @> to_jsonb(uid), false);
  if in_new and not in_old then
    perform public.check_rate_limit(uid, 'apply', 10, interval '24 hours');
  end if;
  return new;
end;
$$;
drop trigger if exists limit_applies on public.shared_jobs;
create trigger limit_applies
  before update on public.shared_jobs
  for each row execute function public.tg_limit_applies();

-- ---- ОТЗЫВЫ: 30/24ч на пользователя + 140/24ч глобально ----
-- Редактирование/смена звёзд (upsert того же id) лимит не тратит.
create or replace function public.tg_limit_reviews()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.reviews where id = new.id) then
    return new;
  end if;
  perform public.check_rate_limit(
    new.author_id, 'review', 30, interval '24 hours');
  perform public.check_rate_limit(
    '__ALL__', 'review_global', 140, interval '24 hours');
  return new;
end;
$$;
drop trigger if exists limit_reviews on public.reviews;
create trigger limit_reviews
  before insert on public.reviews
  for each row execute function public.tg_limit_reviews();

-- ---- СООБЩЕНИЯ: 50/мин на каждого отправителя (антифлуд) ----
create or replace function public.tg_limit_messages()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.check_rate_limit(
    new.sender_id, 'message', 50, interval '1 minute');
  return new;
end;
$$;
drop trigger if exists limit_messages on public.messages;
create trigger limit_messages
  before insert on public.messages
  for each row execute function public.tg_limit_messages();

-- (Необязательно) чистка старого журнала, чтобы не рос бесконечно:
-- delete from public.rate_events where created_at < now() - interval '2 days';
