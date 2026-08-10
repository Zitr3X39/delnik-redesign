import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../utils/censor.dart';
import '../utils/cities.dart';
import '../widgets/city_picker.dart';
import '../widgets/glass.dart';

/// Первичное заполнение анкеты после подтверждения номера.
class ProfileSetupScreen extends StatefulWidget {
  final String phone;
  const ProfileSetupScreen({super.key, required this.phone});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  /// Город выбирается из справочника, а не вводится руками: так мы знаем
  /// координаты города и можем сразу центрировать карту и сортировать ленту.
  String _city = '';
  String? _cityError;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _finish() {
    final formOk = _formKey.currentState!.validate();
    final cityOk = _city.trim().isNotEmpty;
    if (!cityOk) setState(() => _cityError = 'Выберите город');
    if (!formOk || !cityOk) return;
    context.read<JobProvider>().registerUser(
          phone: widget.phone,
          name: _nameController.text.trim(),
          age: int.tryParse(_ageController.text.trim()) ?? 0,
          city: _city.trim(),
        );
    Navigator.pushReplacementNamed(context, JobProvider.takePendingRoute());
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Анкета',
      showBack: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Давайте познакомимся',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Эти данные помогут заказчикам и исполнителям узнавать вас',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Почта подтверждена',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text(
                              widget.phone.isEmpty ? '—' : widget.phone,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock_rounded,
                          size: 18, color: Colors.black38),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Имя или название организации',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: nameCleanValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Возраст',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Укажите возраст';
                    final n = int.tryParse(v);
                    if (n == null || n < 18 || n > 99) return 'От 18 до 99';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CityField(
                  value: _city,
                  errorText: _cityError,
                  onSelected: (RuCity c) => setState(() {
                    _city = c.name;
                    _cityError = null;
                  }),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Заявки вашего города будут показываться первыми. Город можно будет '
                  'изменить в профиле.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 26),
                BigButton(
                  label: 'ЗАВЕРШИТЬ РЕГИСТРАЦИЮ',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.primaryColor,
                  onPressed: _finish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
