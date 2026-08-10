import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/glass.dart';

/// Ввод кода, переданного проверяющему RuStore.
/// Секрет не хранится в APK — правильность проверяет сервер.
class DevLoginScreen extends StatefulWidget {
  const DevLoginScreen({super.key});

  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Введите код проверяющего');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Вход для разработчика',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: Color(0xFF0284C7)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Вход для разработчика',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Введите код из кабинета RuStore. Демо-аккаунт работает с '
                  'обычными лимитами и не получает прав модератора.',
                  style: TextStyle(color: Colors.black54, height: 1.45),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(64)],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Код проверяющего',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('ВОЙТИ ДЛЯ ПРОВЕРКИ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}