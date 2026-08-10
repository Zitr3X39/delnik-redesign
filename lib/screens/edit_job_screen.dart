import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/job.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/censor.dart';
import '../utils/cities.dart';
import '../utils/geo.dart';
import '../widgets/glass.dart';

/// Редактирование своей заявки.
///
/// Отклики, переписка, этапы работы и оценки сохраняются: меняются
/// только условия. После сохранения изменения уходят в облако и видны
/// остальным пользователям, а откликнувшимся приходит сообщение в чат.
class EditJobScreen extends StatefulWidget {
  final Job job;
  const EditJobScreen({super.key, required this.job});

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _streetController;
  late final TextEditingController _houseController;
  late final TextEditingController _workersController;
  late final TextEditingController _payController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isFixedPay;
  late String _category;
  late List<String> _photos;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _titleController = TextEditingController(text: j.title);
    _descriptionController = TextEditingController(text: j.description);

    // Адрес хранится в виде «Улица, д. 12» — разбираем обратно.
    var street = j.address;
    var house = '';
    final marker = j.address.indexOf(', д. ');
    if (marker > 0) {
      street = j.address.substring(0, marker);
      house = j.address.substring(marker + 5);
    }
    _streetController = TextEditingController(text: street);
    _houseController = TextEditingController(text: house);

    _workersController =
        TextEditingController(text: j.workersNeeded.toString());
    _payController = TextEditingController(text: j.payPerHour.toInt().toString());
    _selectedDate = j.date;
    _selectedTime = TimeOfDay(hour: j.date.hour, minute: j.date.minute);
    _isFixedPay = j.isFixedPay;
    _category = j.category;
    _photos = List<String>.from(j.photos);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _streetController.dispose();
    _houseController.dispose();
    _workersController.dispose();
    _payController.dispose();
    super.dispose();
  }

  String _fmtTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay.isBefore(today) ? today : selectedDay,
      firstDate: today,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final provider = context.read<JobProvider>();
    final job = widget.job;

    final street = _streetController.text.trim();
    final house = _houseController.text.trim();
    final address = '$street, д. $house';
    final city = provider.cityOfJob(job).trim().isEmpty
        ? myCity
        : provider.cityOfJob(job).trim();

    var lat = job.lat;
    var lng = job.lng;
    // Адрес изменился — пересчитываем метку, но если геокодер молчит,
    // оставляем старую точку, чтобы заявка не уехала в центр города.
    if (address != job.address) {
      final point = await geocodeAddress(street, house, city: city);
      if (point != null) {
        lat = point.lat;
        lng = point.lng;
      } else {
        final coords = RuCities.coordsOf(city);
        if (coords != null && job.lat == 0 && job.lng == 0) {
          lat = coords.lat;
          lng = coords.lng;
        }
      }
    }

    final date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (!date.isAfter(DateTime.now())) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дата и время должны быть в будущем')),
        );
      }
      return;
    }

    final workers = int.tryParse(_workersController.text.trim()) ??
        job.workersNeeded;
    final pay = double.tryParse(_payController.text.trim().replaceAll(',', '.')) ??
        job.payPerHour;

    final updated = job.copyWithEdits(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      address: address,
      city: city,
      lat: lat,
      lng: lng,
      workersNeeded: workers,
      payPerHour: pay,
      isFixedPay: _isFixedPay,
      date: date,
      category: _category,
      photos: _photos,
    );

    final ok = provider.updateJob(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Заявка обновлена'
            : 'Не удалось сохранить: заявка закрыта, чужая или уже есть отклики'),
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Редактирование заявки',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Заголовок'),
                    validator: requiredCleanValidator,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Описание работы'),
                    validator: requiredCleanValidator,
                    maxLines: 5,
                    maxLength: 600,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Категория',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kJobCategories.map((c) {
                      final selected = c == _category;
                      return ChoiceChip(
                        label: Text(c),
                        avatar: Icon(categoryIcon(c),
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppTheme.primaryColor),
                        selected: selected,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _category = c),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(labelText: 'Улица'),
                    validator: requiredCleanValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _houseController,
                    decoration: const InputDecoration(labelText: 'Дом'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Укажите номер дома'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Город заявки не меняется. Чтобы разместить работу в другом '
                    'городе, создайте новую заявку.',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(
                            '${_selectedDate.day.toString().padLeft(2, '0')}.'
                            '${_selectedDate.month.toString().padLeft(2, '0')}.'
                            '${_selectedDate.year}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_outlined, size: 18),
                          label: Text(_fmtTime24(_selectedTime)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _workersController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Сколько человек нужно'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim()) ?? 0;
                      if (n < 1) return 'Минимум 1 человек';
                      if (n < widget.job.applicants.length) {
                        return 'Уже откликнулось ${widget.job.applicants.length}';
                      }
                      if (n > 50) return 'Не больше 50';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _isFixedPay ? 'Фиксированная оплата' : 'Оплата за час',
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: _isFixedPay,
                          onChanged: (v) => setState(() => _isFixedPay = v),
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _payController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _isFixedPay ? 'Сумма за работу, ₽' : 'Оплата в час, ₽',
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim()) ?? 0;
                      if (n <= 0) return 'Укажите оплату';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Фото',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Лишние снимки можно убрать. Чтобы добавить новые фото, '
                      'создайте заявку заново.',
                      style: TextStyle(
                          color: Colors.black54, fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _photos.map((url) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 92,
                                  height: 92,
                                  color: const Color(0xFFF3F4F6),
                                  child: const Icon(Icons.broken_image_outlined,
                                      color: Colors.black26),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _photos.remove(url)),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: const Icon(Icons.close_rounded,
                                      size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            BigButton(
              label: _saving ? 'СОХРАНЯЕМ…' : 'СОХРАНИТЬ ИЗМЕНЕНИЯ',
              icon: Icons.save_outlined,
              color: AppTheme.primaryColor,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Откликнувшимся придёт сообщение, что условия изменились.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
