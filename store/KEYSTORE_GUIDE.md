# Шаг 1 — Release-ключ (keystore) для RuStore

Сейчас APK подписан **debug-ключом** — с ним в RuStore нельзя.
Нужно создать свой постоянный ключ (один раз на всю жизнь приложения).

## ⚠️ САМОЕ ВАЖНОЕ
Если потеряешь этот ключ или пароль — **больше не сможешь выпускать обновления**
приложения под тем же номером. Сделай резервную копию файла .jks
и паролей в надёжном месте (облако/менеджер паролей).

## Шаги

### 1. Создать ключ
Открой терминал в папке `C:\shabashka_app\android\app` и выполни:

```
keytool -genkey -v -keystore delnik-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias delnik
```

- `keytool` идёт в комплекте с JDK (если не найден — он в папке Android Studio:
  `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`).
- Придумай пароль (запомни!), ответь на вопросы (ФИО/организация/город).
- Появится файл `delnik-release.jks`.

### 2. Прописать пароли
- Скопируй `android/key.properties.template` → `android/key.properties`
  (убери `.template` из имени).
- Заполни свои пароли и путь к .jks. Алиас = `delnik`.

### 3. Собрать релиз
```
flutter build apk --release
```
Готовый файл: `build\app\outputs\flutter-apk\app-release.apk`.
Сборка теперь автоматически подпишется твоим ключом.

### (Альтернатива) AAB вместо APK
RuStore принимает и APK, и AAB. AAB легче для магазина:
```
flutter build appbundle --release
```
Файл: `build\app\outputs\bundle\release\app-release.aab`.

## Перед каждым новым заливом в RuStore
Поднимай версию в `pubspec.yaml` (поле `version:`), например
`1.0.3+3` → `1.0.4+4`. Цифра после `+` (versionCode) должна расти
каждый раз, иначе RuStore отклонит загрузку.

## Безопасность
Файлы `key.properties` и `*.jks` уже добавлены в .gitignore — они НЕ попадут
в архив/репозиторий. Храни их только у себя.
