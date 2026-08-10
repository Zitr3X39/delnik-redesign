import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Флаг переключения «старый UI / новый UI (v2)».
///
/// Живёт на ветке redesign/ui-v2. По умолчанию на этой ветке ВКЛЮЧЁН,
/// чтобы запуск сразу показывал новый дизайн. Выбор сохраняется в
/// SharedPreferences, переключение мгновенное (ValueListenableBuilder
/// в main.dart пересобирает MaterialApp).
///
/// Перед влитием в main решаем: либо выносим флаг (v2 становится
/// единственным UI), либо переворачиваем дефолт на false.
abstract final class UiV2Flag {
  static const String _prefsKey = 'ui_v2_enabled';

  /// Текущее состояние. На ветке редизайна дефолт — новый UI.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  /// Читает сохранённое значение. Вызывается один раз из main()
  /// до runApp. Без await: ValueNotifier обновится синхронно.
  static void init(SharedPreferences prefs) {
    enabled.value = prefs.getBool(_prefsKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Персист не критичен: в текущей сессии флаг уже переключён.
    }
  }
}
