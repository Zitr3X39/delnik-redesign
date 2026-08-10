import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/glass.dart';
import '../app_state.dart';

/// Интро-карусель из 4 экранов с фото-фонами.
/// Показывается один раз при первом запуске (флаг `onboarding_done_v1`
/// в SharedPreferences). После неё — экран входа с галочкой согласия.
///
/// На ПК/планшете фото показывается целиком по центру (без обрезки),
/// а по бокам — размытая версия того же фото, чтобы не было чёрных полос.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  final String image;
  final String title;
  final String text;
  const _OnboardingPage(this.image, this.title, this.text);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _precached = false;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      'assets/onboarding/onboarding_1.jpg',
      'Дельник',
      'Подработка рядом за пару минут. Находите заказы или исполнителей поблизости.',
    ),
    _OnboardingPage(
      'assets/onboarding/onboarding_2.jpg',
      'Для исполнителей',
      'Погрузка, стройка, уборка, разнорабочие — выбирайте заказы рядом и откликайтесь в один тап.',
    ),
    _OnboardingPage(
      'assets/onboarding/onboarding_3.jpg',
      'Для заказчиков',
      'Разместите заявку — исполнители откликнутся быстро. Общайтесь в чате прямо в приложении.',
    ),
    _OnboardingPage(
      'assets/onboarding/onboarding_4.jpg',
      'Безопасность',
      'Дельник — площадка для поиска друг друга. Проверяйте контрагента и договаривайтесь об оплате заранее. Сервис 18+.',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Заранее грузим ВСЕ фото онбординга в кэш, чтобы при листании они
    // появлялись мгновенно, а не «чёрный экран → потом подгрузка».
    if (_precached) return;
    _precached = true;
    for (final p in _pages) {
      precacheImage(AssetImage(p.image), context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    AppState.onboardingDone = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_v1', true);
    } catch (_) {}
    if (!mounted) return;
    // Если пользователь уже вошёл (сессия восстановлена) — сразу на главную,
    // а не на экран входа: иначе после онбординга заставлял логиниться заново.
    final loggedIn =
        Supabase.instance.client.auth.currentSession != null;
    Navigator.pushReplacementNamed(context, loggedIn ? '/home' : '/auth');
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Плавное появление фото (fade-in) вместо «чёрный → картинка».
  /// Если фото уже в кэше (предзагружено) — показываем сразу, без анимации.
  Widget _fadeIn(
      BuildContext context, Widget child, int? frame, bool wasSync) {
    if (wasSync) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) {
              final p = _pages[i];
              // В альбомной ориентации места по высоте сильно меньше: уменьшаем
              // отступы и кегль, иначе текст налипает на картинку и кнопки.
              final landscape =
                  MediaQuery.of(ctx).orientation == Orientation.landscape;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Размытый фон на весь экран (убирает чёрные полосы на ПК).
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                    child: Image.asset(
                      p.image,
                      fit: BoxFit.cover,
                      frameBuilder: _fadeIn,
                      errorBuilder: (_, _, _) =>
                          Container(color: const Color(0xFF0F172A)),
                    ),
                  ),
                  Container(color: const Color(0x55000000)),
                  // Основное фото целиком, по центру, без обрезки.
                  Center(
                    child: Image.asset(
                      p.image,
                      fit: BoxFit.contain,
                      frameBuilder: _fadeIn,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  // Затемнение снизу под текст.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xCC000000),
                          Color(0xF2000000),
                        ],
                        stops: [0.0, 0.45, 0.75, 1.0],
                      ),
                    ),
                  ),
                  // Текст поверх. Блок фиксированной высоты с верхней привязкой —
                  // заголовки на всех страницах оказываются на одном уровне,
                  // а длинный текст скроллится внутри блока, а не ломает вёрстку.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            28, 0, 28, landscape ? 96 : 176),
                        child: SizedBox(
                          height: landscape ? 118 : 168,
                          width: double.infinity,
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: TextStyle(
                                    fontSize: landscape ? 24 : 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: landscape ? 10 : 14),
                                Text(
                                  p.text,
                                  style: TextStyle(
                                    fontSize: landscape ? 14.5 : 16,
                                    color: Colors.white70,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: isLast
                            ? const SizedBox.shrink()
                            : TextButton(
                                onPressed: _finish,
                                child: const Text(
                                  'Пропустить',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      child: BigButton(
                        label: isLast ? 'НАЧАТЬ' : 'ДАЛЕЕ',
                        icon: isLast
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward,
                        color: const Color(0xFF0284C7),
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
