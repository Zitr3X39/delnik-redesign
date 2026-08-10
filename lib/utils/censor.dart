// Цензура для полей ввода (кроме чата между пользователями).
// Ловит русский и английский мат, транслит и leet-написание.

const String profanityMessage =
    'Уберите нецензурные или оскорбительные слова';

const String noDigitsMessage = 'В имени нельзя использовать цифры';

// Русские корни (проверяются по кириллической нормализации).
const List<String> _ruRoots = [
  'хуй', 'хуе', 'хуя', 'хуё', 'хуи', 'хуу', 'наху',
  'пизд', 'еба', 'ебё', 'ебу', 'ебл', 'ебан', 'ёбан',
  'бляд', 'блят', 'блеа', 'блэа',
  'говн', 'дерьм', 'мудак', 'мудач', 'мудил',
  'сука', 'сучар', 'сцук', 'гнид', 'шлюх', 'шалав',
  'пидар', 'пидор', 'пидр', 'педик', 'гомик',
  'чурк', 'хач', 'черножоп', 'жидов', 'нигер', 'ниггер',
  'даун', 'дебил', 'уебан', 'уёб', 'уеб', 'гандон', 'гандён',
  'залуп', 'мандавош', 'ссан', 'обос', 'долбоёб', 'долбоеб',
  'дрочи', 'дроч',
];

// Английские корни (проверяются по латинской нормализации).
const List<String> _enRoots = [
  'fuck', 'shit', 'bitch', 'nigger', 'nigga', 'faggot', 'cunt',
  'asshole', 'motherfuck', 'dick', 'pussy', 'bastard', 'whore',
];

// Латиница/цифры -> кириллица (ловим транслит русского мата).
const Map<String, String> _toCyr = {
  '0': 'о', '1': 'и', '3': 'е', '4': 'ч', '6': 'б', '@': 'а',
  'a': 'а', 'b': 'б', 'c': 'с', 'd': 'д', 'e': 'е', 'f': 'ф', 'g': 'г',
  'h': 'х', 'i': 'и', 'j': 'й', 'k': 'к', 'l': 'л', 'm': 'м', 'n': 'н',
  'o': 'о', 'p': 'р', 'q': 'к', 'r': 'р', 's': 'с', 't': 'т', 'u': 'у',
  'v': 'в', 'w': 'в', 'x': 'х', 'y': 'у', 'z': 'з',
};

// Цифры/leet -> латиница (для английского мата), буквы не трогаем.
const Map<String, String> _toLat = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a',
};

String _normalize(String input, Map<String, String> map) {
  var s = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  s = buffer.toString();
  // Схлопываем повторы букв (хууй -> хуй).
  s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
  // Оставляем только буквы.
  s = s.replaceAll(RegExp(r'[^a-zа-яё]'), '');
  return s;
}

/// Возвращает true, если текст содержит запрещённую лексику.
bool containsProfanity(String? input) {
  if (input == null || input.trim().isEmpty) return false;
  final cyr = _normalize(input, _toCyr);
  for (final root in _ruRoots) {
    if (cyr.contains(root)) return true;
  }
  final lat = _normalize(input, _toLat);
  for (final root in _enRoots) {
    if (lat.contains(root)) return true;
  }
  return false;
}

/// Валидатор для обязательных текстовых полей с проверкой на мат.
String? requiredCleanValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Обязательно';
  if (containsProfanity(value)) return profanityMessage;
  return null;
}

/// Валидатор имени/названия: без цифр, до 50 символов, без мата.
String? nameCleanValidator(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Укажите имя или организацию';
  if (RegExp(r'[0-9]').hasMatch(v)) return noDigitsMessage;
  if (v.length > 50) return 'Слишком длинное имя (макс. 50)';
  if (containsProfanity(v)) return profanityMessage;
  return null;
}
