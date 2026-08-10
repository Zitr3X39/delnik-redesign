-- =====================================================================
-- supabase_patch_v40_3_3.sql
-- Патч для отзывов и рейтинга (задача №е 5).
-- Открывает чтение отзывов всем авторизованным, разрешает
-- запись собственных отзывов и включает realtime.
-- Скрипт идемпотентный — можно запускать повторно.
-- Запуск: Supabase -> SQL Editor -> вставить → Run.
-- =====================================================================

-- Включаем RLS (если ещё не включен)
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Чтение отзывов: доступно всем авторизованным
-- (нужно, чтобы получатель видел отзывы о себе и чужие профили).
DROP POLICY IF EXISTS "reviews_select_all" ON public.reviews;
CREATE POLICY "reviews_select_all"
  ON public.reviews
  FOR SELECT
  TO authenticated
  USING (true);

-- Вставка: можно создавать только свой отзыв (author_id = текущий пользователь).
DROP POLICY IF EXISTS "reviews_insert_own" ON public.reviews;
CREATE POLICY "reviews_insert_own"
  ON public.reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid()::text);

-- Обновление своего отзыва (на случай повторной оценки той же заявки).
DROP POLICY IF EXISTS "reviews_update_own" ON public.reviews;
CREATE POLICY "reviews_update_own"
  ON public.reviews
  FOR UPDATE
  TO authenticated
  USING (author_id = auth.uid()::text)
  WITH CHECK (author_id = auth.uid()::text);

-- Включаем realtime для таблицы reviews (идемпотентно).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'reviews'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
  END IF;
END $$;

-- Профили — чтение доступно всем авторизованным (чтобы видеть чужие карточки).
ALTER TABLE public.shared_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "shared_profiles_select_all" ON public.shared_profiles;
CREATE POLICY "shared_profiles_select_all"
  ON public.shared_profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- Готово. После запуска отзывы будут синхронизироваться между устройствами.
