-- 11_city_and_bans.sql
-- Дельник v1.0.5: город у заявки/профиля, блокировки пользователей,
-- редактирование и удаление заявки автором.
--
-- Важно: все новые поля живут внутри JSON-колонки data, поэтому
-- менять структуру таблиц не нужно. Скрипт только проставляет
-- значения по умолчанию старым записям и добавляет индексы.
-- Запускать один раз в SQL Editor вашего Supabase.

-- 1. Город у старых заявок: было только одно город-по умолчанию (Уфа).
update public.shared_jobs
set data = jsonb_set(data::jsonb, '{city}', '"Уфа"'::jsonb, true)
where coalesce(data::jsonb ->> 'city', '') = '';

-- 2. Профили: город, флаг регистрации и дата создания.
update public.shared_profiles
set data = jsonb_set(data::jsonb, '{city}', '"Уфа"'::jsonb, true)
where coalesce(data::jsonb ->> 'city', '') = '';

update public.shared_profiles
set data = jsonb_set(data::jsonb, '{registered}', 'true'::jsonb, true)
where data::jsonb -> 'registered' is null
  and coalesce(data::jsonb ->> 'name', '') <> '';

update public.shared_profiles
set data = jsonb_set(
    data::jsonb,
    '{createdAt}',
    to_jsonb(to_char(coalesce(updated_at, now()) at time zone 'UTC',
                     'YYYY-MM-DD"T"HH24:MI:SS"Z"')),
    true)
where data::jsonb -> 'createdAt' is null;

-- 3. Индексы под ленту по городу и под панель разработчика.
create index if not exists shared_jobs_city_idx
    on public.shared_jobs (((data::jsonb) ->> 'city'));

create index if not exists shared_profiles_city_idx
    on public.shared_profiles (((data::jsonb) ->> 'city'));

create index if not exists shared_profiles_banned_idx
    on public.shared_profiles (((data::jsonb) ->> 'bannedUntil'));

-- 4. Проверка результата.
select
    (data::jsonb) ->> 'city' as city,
    count(*) as jobs
from public.shared_jobs
group by 1
order by 2 desc;
