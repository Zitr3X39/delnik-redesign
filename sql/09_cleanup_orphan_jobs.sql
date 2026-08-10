-- ============================================================
--  ДЕЛЬНИК · Автоочистка "мёртвых" заявок (v62)
--  Удаляет заявку из общей базы, если:
--   • профиль владельца удалён (аккаунт удалён);
--   • владелец вышел из аккаунта более 3 часов назад и не вернулся.
--  Клиент и так ПРЯЧЕТ такие заявки сразу; эта чистка убирает их
--  из БД физически. Требует расширение pg_cron.
--  Supabase -> Database -> Extensions -> включить pg_cron.
-- ============================================================

create or replace function public.cleanup_orphan_jobs()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 1) Заявки без существующего профиля владельца (аккаунт удалён).
  delete from public.shared_jobs j
  where not exists (
    select 1 from public.shared_profiles p
    where p.id = j.data ->> 'employerId'
  );

  -- 2) Заявки владельцев, вышедших из аккаунта более 3 часов назад.
  delete from public.shared_jobs j
  using public.shared_profiles p
  where p.id = j.data ->> 'employerId'
    and (p.data ->> 'loggedOutAt') is not null
    and (p.data ->> 'loggedOutAt')::timestamptz < now() - interval '3 hours';

  -- 3) Подчищаем осиротевшие сообщения удалённых заявок.
  delete from public.messages m
  where not exists (
    select 1 from public.shared_jobs j where j.id = m.job_id
  );
end;
$$;

-- Разовый прогон прямо сейчас (можно нажать Run отдельно):
-- select public.cleanup_orphan_jobs();

-- Автозапуск каждые 15 минут — ТОЛЬКО если установлен pg_cron.
-- Если pg_cron нет — функция всё равно создана (можно звать вручную),
-- а этот блок не упадёт с ошибкой.
do $do$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'cleanup_orphan_jobs',
      '*/15 * * * *',
      $c$ select public.cleanup_orphan_jobs(); $c$
    );
    raise notice 'pg_cron найден: автоочистка запланирована каждые 15 минут.';
  else
    raise notice 'pg_cron не установлен — автозапуск пропущен. Включите его в Database -> Extensions и запустите этот файл повторно.';
  end if;
end
$do$;
