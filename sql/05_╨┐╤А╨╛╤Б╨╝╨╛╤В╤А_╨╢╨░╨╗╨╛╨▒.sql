-- =====================================================================
-- 05_просмотр_жалоб.sql
-- Удобный список жалоб: кто, на кого, причина, текст, дата.
-- Подтягивает имена из shared_profiles по id.
-- =====================================================================

SELECT
  r.created_at            AS "Когда",
  r.reason                AS "Причина",
  r.details               AS "Текст жалобы",
  r.status                AS "Статус",
  r.reporter_id           AS "ID автора",
  rep.data->>'name'       AS "Автор (имя)",
  r.target_id             AS "ID нарушителя",
  tgt.data->>'name'       AS "Нарушитель (имя)",
  tgt.data->>'phone'      AS "Телефон нарушителя",
  r.job_id                AS "ID заявки"
FROM public.reports r
LEFT JOIN public.shared_profiles rep ON rep.id = r.reporter_id
LEFT JOIN public.shared_profiles tgt ON tgt.id = r.target_id
ORDER BY r.created_at DESC;

-- Пометить жалобу как рассмотренную (подставь её id):
-- UPDATE public.reports SET status = 'reviewed' WHERE id = '<ID_жалобы>';
