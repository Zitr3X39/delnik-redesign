import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/job_provider.dart';
import '../widgets/glass.dart';
import 'dev_login_screen.dart';
import 'legal_viewer_screen.dart';
import 'profile_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  final bool _useEmail = true;
  bool _consent = false;
  int _secondsLeft = 0;

  static const _linkStyle = TextStyle(
    color: Color(0xFF0284C7),
    decoration: TextDecoration.underline,
    fontSize: 12,
    height: 1.35,
  );

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LegalViewerScreen(
          title: 'Пользовательское соглашение',
          assetPath: 'assets/legal/user_agreement.md',
        ),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LegalViewerScreen(
          title: 'Политика конфиденциальности',
          assetPath: 'assets/legal/privacy_policy.md',
        ),
      ),
    );
  }

  Future<void> _recordConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('consent_version', 'delnik-v1');
      await prefs.setString(
          'consent_at', DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  Widget _buildConsent() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Checkbox(
              value: _consent,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() => _consent = v ?? false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 12, height: 1.35),
                  children: [
                    const TextSpan(
                        text: 'Мне исполнилось 18 лет, я согласен(а) с '),
                    TextSpan(
                        text: 'Пользовательским соглашением',
                        style: _linkStyle,
                        recognizer: _termsRecognizer),
                    const TextSpan(text: ' и '),
                    TextSpan(
                        text: 'Политикой конфиденциальности',
                        style: _linkStyle,
                        recognizer: _privacyRecognizer),
                    const TextSpan(
                        text:
                            ', и даю согласие на обработку персональных данных.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String get _digits =>
      _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  void _tick() {
    if (!mounted || _secondsLeft <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      _tick();
    });
  }

  String get _email => _emailController.text.trim().toLowerCase();

  // Список известных одноразовых/временных почтовых доменов.
  // Вход на такие адреса не пускаем (простая защита от спама).
  static const _disposableDomains = <String>{
    'mailinator.com', '10minutemail.com', 'guerrillamail.com',
    'guerrillamail.info', 'temp-mail.org', 'tempmail.dev', 'tempmailo.com',
    'trashmail.com', 'yopmail.com', 'getnada.com', 'nada.email',
    'dispostable.com', 'fakeinbox.com', 'sharklasers.com', 'grr.la',
    'maildrop.cc', 'mailnesia.com', 'mohmal.com', 'throwawaymail.com',
    'emailondeck.com', 'moakt.com', 'mailcatch.com', 'discard.email',
    'tempinbox.com', '20minutemail.com', '1secmail.com', 'mail-temp.com',
    'tempr.email', 'burnermail.io', 'mintemail.com', 'spamgourmet.com',
    'tempmail.plus', 'minuteinbox.com',
  };

  bool _isDisposable(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return false;
    final domain = email.substring(at + 1).toLowerCase().trim();
    return _disposableDomains.contains(domain);
  }

  Future<void> _sendCode() async {
    if (!_consent) {
      _snack('Подтвердите согласие с условиями (галочка ниже)');
      return;
    }
    if (_useEmail) {
      if (!_email.contains('@') || _email.length < 5) {
        _snack('Введите корректный email');
        return;
      }
      if (_isDisposable(_email)) {
        _snack('Одноразовые почты не поддерживаются. Укажите постоянный email.');
        return;
      }
    } else if (_digits.length < 10) {
      _snack('Введите корректный номер телефона');
      return;
    }
    try {
      if (_useEmail) {
        await Supabase.instance.client.auth
            .signInWithOtp(email: _email, shouldCreateUser: true);
      } else {
        await Supabase.instance.client.auth
            .signInWithOtp(phone: '+7$_digits');
      }
    } catch (e) {
      _snack('Не удалось отправить код: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _codeSent = true;
      _secondsLeft = 30;
    });
    _tick();
    _snack(_useEmail
        ? 'Код отправлен на $_email. Проверьте почту, в том числе папку «Спам».'
        : 'Код отправлен на +7$_digits');
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length < 4) {
      _snack('Введите код из сообщения');
      return;
    }
    final auth = Supabase.instance.client.auth;
    var ok = false;
    try {
      final res = _useEmail
          ? await auth.verifyOTP(
              type: OtpType.email,
              email: _email,
              token: code,
            )
          : await auth.verifyOTP(
              type: OtpType.sms,
              phone: '+7$_digits',
              token: code,
            );
      ok = res.session != null;
    } catch (_) {
      // verifyOTP иногда бросает исключение, хотя сессия уже создана
      // (повтор запроса / гонка сети). Прежде чем ругаться на код —
      // проверяем реальную сессию, чтобы верный код не отклонялся зря.
      ok = auth.currentSession != null;
    }
    if (!ok) ok = auth.currentSession != null;
    if (!ok) {
      _snack('Код неверный или устарел. Запросите новый и введите'
          ' последний пришедший код.');
      return;
    }
    if (!mounted) return;
    final provider = context.read<JobProvider>();
    await _recordConsent();
    await provider.onLoggedIn();
    if (!mounted) return;
    if (provider.isRegistered) {
      Navigator.pushReplacementNamed(context, JobProvider.takePendingRoute());
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
              phone: _useEmail ? _email : '+7$_digits'),
        ),
      );
    }
  }

  /// Демо-вход RuStore: анонимная сессия получает доступ только после
  /// серверной проверки кода и никогда не получает прав модератора.
  Future<void> _devLogin() async {
    if (!_consent) {
      _snack('Подтвердите согласие с условиями (галочка ниже)');
      return;
    }
    final reviewerCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DevLoginScreen()),
    );
    if (reviewerCode == null || !mounted) return;

    final auth = Supabase.instance.client.auth;
    try {
      await auth.signInAnonymously();
      final approved = await Supabase.instance.client.rpc(
        'activate_reviewer_session',
        params: {'p_code': reviewerCode},
      );
      if (approved != true) {
        throw const AuthException('Неверный код проверяющего');
      }
    } catch (_) {
      try {
        await auth.signOut();
      } catch (_) {}
      if (mounted) {
        _snack('Код проверяющего неверный или временно заблокирован');
      }
      return;
    }

    if (!mounted) return;
    final provider = context.read<JobProvider>();
    await _recordConsent();
    await provider.onLoggedIn();
    if (!mounted) return;
    if (provider.isRegistered) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileSetupScreen(phone: ''),
        ),
      );
    }
  }

  void _editPhone() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _secondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.bolt,
                        color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 16),
                  const Text('ДЕЛЬНИК',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  const Text('Быстрые подработки рядом',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 28),
                  if (_useEmail)
                    TextField(
                      controller: _emailController,
                      enabled: !_codeSent,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    )
                  else
                    TextField(
                      controller: _phoneController,
                      enabled: !_codeSent,
                      decoration: const InputDecoration(
                        labelText: 'Номер телефона',
                        prefixText: '+7 ',
                        hintText: '999 123 45 67',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_PhoneInputFormatter()],
                    ),
                  if (_codeSent) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _editPhone,
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(_useEmail
                            ? 'Изменить email'
                            : 'Изменить номер'),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero),
                      ),
                    ),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 12,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Код подтверждения',
                        hintText: '••••••',
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _secondsLeft > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 16, color: Colors.black38),
                                const SizedBox(width: 6),
                                Text(
                                  'Отправить код повторно можно через '
                                  '$_secondsLeft сек.',
                                  style: const TextStyle(
                                      color: Colors.black45, fontSize: 12.5),
                                ),
                              ],
                            )
                          : TextButton.icon(
                              onPressed: () => _sendCode(),
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 18),
                              label: const Text('Отправить код повторно'),
                            ),
                    ),
                  ],
                  if (!_codeSent) _buildConsent(),
                  const SizedBox(height: 12),
                  BigButton(
                    label: _codeSent ? 'ПОДТВЕРДИТЬ' : 'ПОЛУЧИТЬ КОД',
                    icon: _codeSent
                        ? Icons.check_circle_outline
                        : Icons.sms_outlined,
                    color: const Color(0xFF0284C7),
                    onPressed: () => _codeSent ? _verifyCode() : _sendCode(),
                  ),
                  if (!_codeSent) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _devLogin,
                      icon: const Icon(Icons.developer_mode_rounded, size: 18),
                      label: const Text('Вход для разработчика'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Нормализует ввод/вставку телефона: убирает всё кроме цифр и оставляет
/// последние 10 цифр (отбрасывает код страны 7/8 при вставке +7.../8...).
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length > 10) d = d.substring(d.length - 10);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}
