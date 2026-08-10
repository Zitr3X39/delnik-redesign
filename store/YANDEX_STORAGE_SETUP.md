# Хранение фото в Yandex Object Storage (по 152-ФЗ)

Цель: фото заявок и чата хранятся в РФ (Yandex Object Storage — S3-совместимое,
серверы в России, соответствует 152-ФЗ), старые файлы удаляются сами
(lifecycle), а секретные ключи НИКОГДА не попадают в APK.

---

## Схема (почему это безопасно)

```
1. APK  →  твой Cloudflare Worker /sign   (Worker подписывает ссылку ключом Yandex)
2. Worker  →  возвращает временную ссылку для загрузки (presigned URL)
3. APK  →  заливает фото НАПРЯМУЮ в Yandex (РФ), мимо Cloudflare
4. APK  →  сохраняет публичную ссылку фото в БД
```

Сами фото идут с телефона прямо в Yandex (в РФ). Worker только «подписывает»
ссылку — через него файлы не проходят. Секретный ключ лежит только в
Worker (как secret), в приложении его нет.

---

## Шаг 1. Аккаунт Yandex Cloud и грант

1. Зайди на https://console.yandex.cloud → создай платёжный аккаунт.
2. Новым пользователям начисляют стартовый грант (физлицам — 4000 ₽).
3. Нужно привязать банковскую карту (требование Yandex), но пока ты в гранте
   и бесплатных лимитах — спишется 0 ₽.

Бесплатные лимиты Object Storage: первый 1 ГБ хранения, 10 000 загрузок (PUT)
в месяц и первые 100 ГБ исходящего трафика в месяц — бесплатно.

---

## Шаг 2. Создать бакет

Консоль → **Object Storage** → **Создать бакет**:
- Имя: `delnik-photos` (можно другое — запомни его).
- Класс: **Standard**.
- Доступ на чтение объектов: **Публичный** (чтобы фото открывались по ссылке).
  Запись оставь закрытой — заливать будем только по подписанной ссылке.

Публичная ссылка на файл будет вида:
`https://storage.yandexcloud.net/delnik-photos/<имя-файла>`

---

## Шаг 3. Сервисный аккаунт и статические ключи

1. Консоль → **IAM** → **Сервисные аккаунты** → создай аккаунт (напр. `delnik-uploader`).
2. Дай ему роль `storage.uploader` (и `storage.viewer` при желании).
3. Создай для него **статический ключ доступа** → получишь два значения:
   - **Key ID** (публичный)
   - **Secret key** (секретный — показывается ОДИН раз, сохрани!)

Эти ключи НЕ вставляй в приложение. Они пойдут только в Worker (шаг 5).

---

## Шаг 4. Автоудаление старых файлов (lifecycle)

Открой бакет → **Настройки** → вкладка **Lifecycle** → **Настроить** → добавь правила:
- **Фото чата**: префикс `chat/`, удалять через **30 дней** (переписка не копится).
- **Фото заявок**: префикс `jobs/`, удалять через **60–90 дней** (заявки к этому
  времени уже закрыты).

Так память чистится сама, без кода и без cron.

---

## Шаг 5. Подписывающий эндпоинт в Cloudflare Worker

В проекте Worker’а установи библиотеку подписи:
```
npm i aws4fetch
```

Добавь в Worker обработку пути `/sign` (пример на JS):
```js
import { AwsClient } from 'aws4fetch'

export default {
  async fetch(request, env) {
    const url = new URL(request.url)

    if (url.pathname === '/sign') {
      // key — имя файла, напр. jobs/1699999999_ab12.jpg или chat/...
      const key = url.searchParams.get('key')
      if (!key || key.includes('..')) return new Response('bad key', { status: 400 })

      const aws = new AwsClient({
        accessKeyId: env.YC_KEY_ID,
        secretAccessKey: env.YC_SECRET,
        region: 'ru-central1',
        service: 's3',
      })

      const target = `https://storage.yandexcloud.net/${env.YC_BUCKET}/${key}`
      // подписываем PUT-ссылку на 10 минут
      const signed = await aws.sign(target + '?X-Amz-Expires=600', {
        method: 'PUT',
        aws: { signQuery: true },
      })

      return new Response(JSON.stringify({ url: signed.url }), {
        headers: { 'content-type': 'application/json' },
      })
    }

    // ... остальные маршруты твоего Worker’а ...
    return new Response('ok')
  },
}
```

Секреты задай через wrangler (они не попадут в код и в git):
```
npx wrangler secret put YC_KEY_ID
npx wrangler secret put YC_SECRET
npx wrangler secret put YC_BUCKET   # напр. delnik-photos
```
Потом `npx wrangler deploy`.

---

## Шаг 6. Замена загрузки в приложении

Это применю Я, когда бэкенд будет готов (чтобы не сломать текущие тесты).
Функция `uploadPhoto` в `lib/providers/job_provider.dart` станет такой
(вместо загрузки в Supabase Storage):

```dart
// вверху файла: import 'dart:convert'; import 'package:http/http.dart' as http;
static const String _kSignBase = 'https://shabashka.arturbalt9.workers.dev';
static const String _kBucket = 'delnik-photos';

/// Загружает фото в Yandex Object Storage и возвращает публичную ссылку.
Future<String?> uploadPhoto(Uint8List bytes, {String folder = 'jobs'}) async {
  try {
    final key =
        '$folder/${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.jpg';
    // 1) берём подписанную ссылку у Worker’а
    final sign = await http.get(
        Uri.parse('$_kSignBase/sign?key=${Uri.encodeComponent(key)}'));
    if (sign.statusCode != 200) return null;
    final putUrl = (jsonDecode(sign.body) as Map)['url'] as String;
    // 2) льём фото напрямую в Yandex
    final put = await http.put(Uri.parse(putUrl), body: bytes);
    if (put.statusCode != 200 && put.statusCode != 201) return null;
    // 3) публичная ссылка
    return 'https://storage.yandexcloud.net/$_kBucket/$key';
  } catch (_) {
    return null;
  }
}
```
В чате вызов станет `uploadPhoto(bytes, folder: 'chat')`, чтобы lifecycle чата
(30 дней) работал отдельно от фото заявок.

---

## Что мне прислать, чтобы я довёл код

1. Имя бакета (если не `delnik-photos`).
2. Подтверждение, что Worker с `/sign` развёрнут и секреты заданы.
**НИКОГДА не присылай мне секретный ключ (Secret key).** Он нужен только в wrangler secret.
