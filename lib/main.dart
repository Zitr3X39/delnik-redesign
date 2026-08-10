import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/job_provider.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/job_detail_screen.dart';
import 'theme/app_theme.dart';
import 'services/reminder_service.dart';
import 'screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var supabaseReady = false;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }
  await _bootApp(supabaseReady);
}

/// Запуск приложения. `supabaseReady` известен заранее (init уже сделан),
/// поэтому «Повторить» не дублирует Supabase.initialize.
Future<void> _bootApp(bool supabaseReady) async {
  // Локальные напоминания «за 3 часа до начала работы» (локально, без сервера).
  await PushService.instance.init();
  if (supabaseReady && Supabase.instance.client.auth.currentSession != null) {
    PushService.instance.register();
  }
  await ReminderService.instance.init();
  ReminderService.instance.requestPermission();
  bool onboardingDone = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool('onboarding_done_v1') ?? false;
  } catch (_) {}
  AppState.onboardingDone = onboardingDone;
  if (!supabaseReady) {
    runApp(const ServerErrorApp());
    return;
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => JobProvider()..init(),
      child: ShabashkaApp(onboardingDone: onboardingDone),
    ),
  );
}

/// «Повторить» на экране ошибки сервера: пробуем инициализацию заново
/// (она не удалась в первый раз, поэтому повтор безопасен), затем запускаем
/// приложение. В отличие от старого `onPressed: main`, не задваивает
/// Supabase.initialize, если тот уже успел выполниться.
void _retryBoot() {
  runApp(const ServerErrorApp());
  Future(() async {
    var supabaseReady = false;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      supabaseReady = true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
    await _bootApp(supabaseReady);
  });
}

class ServerErrorApp extends StatelessWidget {
  const ServerErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 56, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                const Text(
                  'Нет связи с сервером',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Проверьте интернет и попробуйте ещё раз. '
                  'Если ошибка повторяется — сервер временно недоступен, '
                  'зайдите позже.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF607089)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _retryBoot,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/// true, если есть активная сессия Supabase.
bool _isLoggedIn() {
  try {
    return Supabase.instance.client.auth.currentSession != null;
  } catch (_) {
    return false;
  }
}

/// Пускает на защищённый экран только при активной сессии. Иначе —
/// возвращает экран входа (закрывает дыру с прямым переходом на #/home).
Widget _guard(Widget page) {
  // Первый заход (онбординг не пройден) — всегда на онбординг,
  // какую бы ссылку пользователь ни открыл.
  if (!_isLoggedIn() && !AppState.onboardingDone) return const OnboardingScreen();
  // Без активной сессии — только на экран входа (нельзя на главную без входа).
  if (!_isLoggedIn()) return const AuthScreen();
  return page;
}

class ShabashkaApp extends StatefulWidget {
  const ShabashkaApp({super.key, this.onboardingDone = false});

  final bool onboardingDone;

  @override
  State<ShabashkaApp> createState() => _ShabashkaAppState();
}

class _ShabashkaAppState extends State<ShabashkaApp>
    with WidgetsBindingObserver {
  int _resumeTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Только веб: при возврате во вкладку CanvasKit иногда теряет
    // graphics-контекст и экран становится чёрным. Пересобираем
    // дерево, чтобы форсировать перерисовку. Навигация сохраняется
    // благодаря GlobalKey навигатора. На мобильных это не нужно.
    if (kIsWeb && state == AppLifecycleState.resumed) {
      setState(() => _resumeTick++);
      WidgetsBinding.instance.scheduleWarmUpFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingDone = widget.onboardingDone;
    final loggedIn = _isLoggedIn();
    final requestedRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final requestedJobRoute = requestedRoute.startsWith('/job/')
        ? requestedRoute
        : null;
    if (requestedJobRoute != null && (!onboardingDone || !loggedIn)) {
      JobProvider.pendingJobId = requestedJobRoute.substring('/job/'.length);
    }
    return MaterialApp(
      scaffoldMessengerKey: JobProvider.messengerKey,
      navigatorKey: JobProvider.navigatorKey,
      title: 'Дельник',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _NoGlowScrollBehavior(),
      // На телефоне в браузере системный масштаб шрифта раздувал интерфейс
      // (выглядело как 125%). Фиксируем масштаб на 100%.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.0),
          ),
          child: KeyedSubtree(
            key: ValueKey(_resumeTick),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      theme: AppTheme.lightTheme,
      initialRoute: (!loggedIn && !onboardingDone)
          ? '/onboarding'
          : (loggedIn ? (requestedJobRoute ?? '/home') : '/auth'),
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/auth': (_) => const AuthScreen(),
        '/home': (_) => _guard(const HomeScreen()),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/job/')) {
          final jobId = name.substring('/job/'.length);
          if (jobId.isNotEmpty) {
            if (!_isLoggedIn()) {
              JobProvider.pendingJobId = jobId;
            }
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => _guard(JobDetailScreen(jobId: jobId)),
            );
          }
        }
        return null;
      },
    );
  }
}

/// Убирает «резинку»/свечение при перекрутке списков — из-за них при
/// резком свайпе вверх-вниз на миг искажался интерфейс.
class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
